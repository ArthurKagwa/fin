"""Ledger domain services — invariants live here, not in views.

set_allocations enforces the US-06 invariant; dashboard_summary powers US-13.
"""

from __future__ import annotations

from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .models import Allocation, Bucket, Deduction, Expense, IncomeEvent


@transaction.atomic
def set_allocations(income_event: IncomeEvent, splits: list[dict]) -> None:
    """Replace the allocation split of an income event atomically (US-06).

    splits: [{"bucket": Bucket, "amount_minor": int}, ...]
    Raises ValidationError if the sum exceeds the income amount (AC-2).
    """
    total = sum(s["amount_minor"] for s in splits)
    if total > income_event.amount_minor:
        raise ValidationError(
            {
                "allocations": (
                    f"Allocated {total} exceeds income {income_event.amount_minor}."
                )
            }
        )
    income_event.allocations.all().delete()
    Allocation.objects.bulk_create(
        Allocation(
            user=income_event.user,
            income_event=income_event,
            bucket=s["bucket"],
            amount_minor=s["amount_minor"],
        )
        for s in splits
    )


@transaction.atomic
def save_paycheque(
    user,
    *,
    gross_minor: int,
    occurred_on,
    source: str,
    note: str = "",
    deductions: list[dict],
    instance: IncomeEvent | None = None,
) -> IncomeEvent:
    """Create or update a paycheque (US-21). Take-home is derived, never given.

    deductions: [{"label": str, "amount_minor": int}, ...]
    Enforces: Σ deductions ≤ gross (AC-2); on edit, new take-home must cover
    existing allocations (AC-4, FR-08 rule).
    """
    total_deductions = sum(d["amount_minor"] for d in deductions)
    if total_deductions > gross_minor:
        raise ValidationError(
            {"deductions": f"Deductions {total_deductions} exceed gross {gross_minor}."}
        )
    takehome = gross_minor - total_deductions
    if takehome <= 0:
        raise ValidationError({"deductions": "Take-home must be above zero."})

    if instance is not None:
        allocated = instance.allocated_minor()
        if takehome < allocated:
            raise ValidationError(
                {
                    "deductions": (
                        f"New take-home {takehome} is below the {allocated} already "
                        "allocated. Fix allocations first."
                    )
                }
            )
        income = instance
    else:
        income = IncomeEvent(user=user)

    income.kind = IncomeEvent.Kind.PAYCHEQUE
    income.gross_minor = gross_minor
    income.amount_minor = takehome
    income.occurred_on = occurred_on
    income.source = source
    income.note = note
    income.save()
    income.deductions.all().delete()
    Deduction.objects.bulk_create(
        Deduction(
            user=user,
            income_event=income,
            label=d["label"],
            amount_minor=d["amount_minor"],
            sort_order=i,
        )
        for i, d in enumerate(deductions)
    )
    return income


def prefill_deductions(user, source: str) -> list[dict]:
    """US-22: deduction lines of the latest paycheque with the same source."""
    last = (
        IncomeEvent.objects.filter(
            user=user, kind=IncomeEvent.Kind.PAYCHEQUE, source__iexact=source.strip()
        )
        .order_by("-occurred_on", "-created_at")
        .first()
    )
    if last is None:
        return []
    return [
        {"label": d.label, "amount_minor": d.amount_minor}
        for d in last.deductions.all()
    ]


def earnings_summary(user, month=None) -> dict:
    """US-23: gross vs take-home for one month plus an all-time summary.

    Rate is None (n/a) when a period has no paycheques — never a fake 0%.
    """
    today = timezone.localdate()
    month = month or today.replace(day=1)
    if month.month == 12:
        next_month = month.replace(year=month.year + 1, month=1)
    else:
        next_month = month.replace(month=month.month + 1)

    def totals(qs):
        pay = qs.filter(kind=IncomeEvent.Kind.PAYCHEQUE).aggregate(
            gross=Sum("gross_minor"), takehome=Sum("amount_minor")
        )
        other = (
            qs.filter(kind=IncomeEvent.Kind.OTHER).aggregate(s=Sum("amount_minor"))["s"]
            or 0
        )
        gross = pay["gross"] or 0
        takehome = pay["takehome"] or 0
        deductions = gross - takehome
        return {
            "gross": gross,
            "takehome": takehome,
            "deductions": deductions,
            "other_income": other,
            "rate_pct": round(deductions * 100 / gross, 1) if gross else None,
        }

    month_qs = IncomeEvent.objects.filter(
        user=user, occurred_on__gte=month, occurred_on__lt=next_month
    )
    return {
        "month": month,
        "month_totals": totals(month_qs),
        "alltime_totals": totals(IncomeEvent.objects.filter(user=user)),
        "entries": list(month_qs.prefetch_related("deductions")),
    }


def unallocated_total_minor(user) -> int:
    """Σ income − Σ allocations, never stored (NFR-09)."""
    income = (
        IncomeEvent.objects.filter(user=user).aggregate(s=Sum("amount_minor"))["s"]
        or 0
    )
    allocated = (
        Allocation.objects.filter(user=user).aggregate(s=Sum("amount_minor"))["s"] or 0
    )
    return income - allocated


def dashboard_summary(user, month=None) -> dict:
    """US-13: per-bucket planned/allocated/spent/remaining + pace, for a month."""
    today = timezone.localdate()
    month = month or today.replace(day=1)

    buckets = []
    for bucket in Bucket.objects.filter(user=user, archived_at__isnull=True):
        month_alloc = (
            bucket.allocations.filter(
                income_event__occurred_on__gte=month,
            ).aggregate(s=Sum("amount_minor"))["s"]
            or 0
        )
        month_spent = (
            bucket.expenses.filter(
                deleted_at__isnull=True, occurred_on__gte=month
            ).aggregate(s=Sum("amount_minor"))["s"]
            or 0
        )
        balance = bucket.balance_minor()
        buckets.append(
            {
                "bucket": bucket,
                "planned_minor": bucket.planned_minor,
                "allocated_this_month": month_alloc,
                "spent_this_month": month_spent,
                "balance_minor": balance,
                # US-20 AC-2: carried-over = balance net of this month's movement.
                "carried_over_minor": balance - month_alloc + month_spent,
                "goal_minor": bucket.goal_minor,
            }
        )

    return {
        "month": month,
        "buckets": buckets,
        "unallocated_minor": unallocated_total_minor(user),
        "days_elapsed": (today - month).days + 1 if month <= today else 0,
    }
