from django.contrib.auth.decorators import login_required
from django.db import transaction
from django.shortcuts import redirect, render

from .forms import RecurringPaymentForm
from .models import RatePeriod, RecurringPayment


@login_required
def recurring_list(request):
    """US-09: registry of recurring payments; creating one opens its first
    rate period (US-10)."""
    if request.method == "POST":
        form = RecurringPaymentForm(request.POST, user=request.user)
        if form.is_valid():
            with transaction.atomic():
                payment = form.save(commit=False)
                payment.user = request.user
                payment.save()
                RatePeriod.objects.create(
                    user=request.user,
                    recurring_payment=payment,
                    amount_minor=form.cleaned_data["amount_minor"],
                    effective_from=payment.start_on,
                )
            return redirect("recurring-list")
    else:
        form = RecurringPaymentForm(user=request.user)
    payments = RecurringPayment.objects.filter(user=request.user)
    return render(
        request, "recurring/list.html", {"payments": payments, "form": form}
    )
