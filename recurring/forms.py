from django import forms
from django.utils import timezone

from ledger.models import Bucket

from .models import RecurringPayment


class RecurringPaymentForm(forms.ModelForm):
    amount_minor = forms.IntegerField(
        min_value=1, label="Amount (minor units)"
    )  # becomes the first RatePeriod (US-10)

    class Meta:
        model = RecurringPayment
        fields = ["name", "bucket", "frequency", "interval_days", "start_on", "end_on"]
        widgets = {
            "start_on": forms.DateInput(attrs={"type": "date"}),
            "end_on": forms.DateInput(attrs={"type": "date"}),
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["start_on"].initial = timezone.localdate()
        if user is not None:
            self.fields["bucket"].queryset = Bucket.objects.filter(
                user=user, archived_at__isnull=True
            )

    def clean(self):
        data = super().clean()
        if data.get("frequency") == RecurringPayment.Frequency.CUSTOM and not data.get(
            "interval_days"
        ):
            self.add_error("interval_days", "Required for a custom frequency.")
        if (
            data.get("end_on")
            and data.get("start_on")
            and data["end_on"] < data["start_on"]
        ):
            self.add_error("end_on", "End must be on or after start.")
        return data
