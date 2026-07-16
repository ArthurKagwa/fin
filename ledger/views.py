from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import ValidationError
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone

from .forms import BucketForm, ExpenseForm, IncomeForm
from .models import Bucket, IncomeEvent
from .services import dashboard_summary, set_allocations


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
    """US-04: log money in, then allocate."""
    if request.method == "POST":
        form = IncomeForm(request.POST)
        if form.is_valid():
            income = form.save(commit=False)
            income.user = request.user
            income.save()
            return redirect("income-allocate", pk=income.pk)
    else:
        form = IncomeForm()
    incomes = IncomeEvent.objects.filter(user=request.user)[:50]
    return render(request, "ledger/income.html", {"incomes": incomes, "form": form})


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
