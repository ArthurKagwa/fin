"""Ledger domain services — invariants live here, not in views.

set_allocations enforces the US-06 invariant; dashboard_summary powers US-13.
"""

from __future__ import annotations

from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .models import Allocation, Bucket, Expense, IncomeEvent


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
