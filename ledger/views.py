from datetime import datetime

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import ValidationError
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone

from .forms import BucketForm, DeductionFormSet, ExpenseForm, IncomeEntryForm
from .models import Bucket, IncomeEvent
from .services import (
    dashboard_summary,
    earnings_summary,
    prefill_deductions,
    save_paycheque,
    set_allocations,
)


@login_required
def dashboard(request):
    """US-13: where-am-I view. Design spec screen #3."""
    return render(request, "ledger/dashboard.html", dashboard_summary(request.user))


@login_required
def bucket_list(request):
    """US-05: create and archive buckets."""
    if request.method == "POST":
        form = BucketForm(request.POST)
        if form.is_valid():
            bucket = form.save(commit=False)
            bucket.user = request.user
            bucket.save()
            return redirect("bucket-list")
    else:
        form = BucketForm()
    buckets = Bucket.objects.filter(user=request.user, archived_at__isnull=True)
    return render(request, "ledger/buckets.html", {"buckets": buckets, "form": form})


@login_required
def bucket_archive(request, pk):
    if request.method == "POST":
        bucket = get_object_or_404(Bucket, pk=pk, user=request.user)
        bucket.archived_at = timezone.now()
        bucket.save()
    return redirect("bucket-list")


@login_required
def income_list(request):
    """US-04/US-21: one entry form; paycheque fields activate by kind (FR-22)."""
    error = None
    if request.method == "POST":
        form = IncomeEntryForm(request.POST)
        formset = DeductionFormSet(request.POST)
        if form.is_valid() and formset.is_valid():
            if form.cleaned_data["kind"] == IncomeEvent.Kind.PAYCHEQUE:
                deductions = [
                    {
                        "label": f.cleaned_data["label"],
                        "amount_minor": f.cleaned_data["amount_minor"],
                    }
                    for f in formset
                    if f.cleaned_data.get("label")
                ]
                try:
                    income = save_paycheque(
                        request.user,
                        gross_minor=form.cleaned_data["gross_minor"],
                        occurred_on=form.cleaned_data["occurred_on"],
                        source=form.cleaned_data["source"],
                        note=form.cleaned_data["note"],
                        deductions=deductions,
                    )
                    return redirect("income-allocate", pk=income.pk)
                except ValidationError as e:
                    error = "; ".join(e.message_dict.get("deductions", e.messages))
            else:
                income = IncomeEvent.objects.create(
                    user=request.user,
                    kind=IncomeEvent.Kind.OTHER,
                    amount_minor=form.cleaned_data["amount_minor"],
                    occurred_on=form.cleaned_data["occurred_on"],
                    source=form.cleaned_data["source"],
                    note=form.cleaned_data["note"],
                )
                return redirect("income-allocate", pk=income.pk)
    else:
        form = IncomeEntryForm()
        formset = DeductionFormSet()
    incomes = IncomeEvent.objects.filter(user=request.user)[:50]
    return render(
        request,
        "ledger/income.html",
        {"incomes": incomes, "form": form, "formset": formset, "error": error},
    )


@login_required
def income_allocate(request, pk):
    """US-06: split an income event across buckets; over-allocation blocked."""
    income = get_object_or_404(IncomeEvent, pk=pk, user=request.user)
    buckets = Bucket.objects.filter(user=request.user, archived_at__isnull=True)
    error = None
    if request.method == "POST":
        splits = []
        for bucket in buckets:
            raw = request.POST.get(f"bucket_{bucket.pk}", "").strip()
            if raw and raw != "0":
                try:
                    amount = int(raw)
                except ValueError:
                    error = f"'{raw}' is not a whole number."
                    break
                if amount > 0:
                    splits.append({"bucket": bucket, "amount_minor": amount})
        if error is None:
            try:
                set_allocations(income, splits)
                return redirect("dashboard")
            except ValidationError as e:
                error = "; ".join(e.message_dict.get("allocations", e.messages))
    existing = {a.bucket_id: a.amount_minor for a in income.allocations.all()}
    rows = [
        {"bucket": b, "current": existing.get(b.pk, "")} for b in buckets
    ]
    return render(
        request,
        "ledger/allocate.html",
        {"income": income, "rows": rows, "error": error},
    )


@login_required
def deduction_prefill(request):
    """US-22: JSON deduction lines of the latest paycheque for ?source=."""
    source = request.GET.get("source", "")
    return JsonResponse({"deductions": prefill_deductions(request.user, source)})


@login_required
def earnings_report(request):
    """US-23: gross vs take-home, monthly + all-time."""
    month = None
    raw = request.GET.get("month")
    if raw:
        try:
            month = datetime.strptime(raw, "%Y-%m").date().replace(day=1)
        except ValueError:
            month = None
    return render(
        request, "ledger/earnings.html", earnings_summary(request.user, month)
    )


@login_required
def expense_add(request):
    """US-07: fast expense entry. Overspend is allowed, never blocked."""
    if request.method == "POST":
        form = ExpenseForm(request.POST, user=request.user)
        if form.is_valid():
            expense = form.save(commit=False)
            expense.user = request.user
            expense.save()
            if expense.bucket.balance_minor() < 0:
                messages.warning(
                    request, f"{expense.bucket.name} is now overspent."
                )
            else:
                messages.success(request, "Saved.")
            return redirect("expense-add")
    else:
        form = ExpenseForm(user=request.user)
    return render(request, "ledger/expense.html", {"form": form})
