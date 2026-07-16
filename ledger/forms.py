from django import forms
from django.utils import timezone

from .models import Bucket, Expense, IncomeEvent


class BucketForm(forms.ModelForm):
    class Meta:
        model = Bucket
        fields = ["name", "planned_minor", "goal_minor"]
        labels = {
            "planned_minor": "Planned per month (minor units)",
            "goal_minor": "Goal (minor units, optional)",
        }


class IncomeForm(forms.ModelForm):
    class Meta:
        model = IncomeEvent
        fields = ["amount_minor", "occurred_on", "source", "note"]
        widgets = {"occurred_on": forms.DateInput(attrs={"type": "date"})}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["occurred_on"].initial = timezone.localdate()


class ExpenseForm(forms.ModelForm):
    class Meta:
        model = Expense
        fields = ["amount_minor", "bucket", "occurred_on", "payee", "note"]
        widgets = {"occurred_on": forms.DateInput(attrs={"type": "date"})}

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["occurred_on"].initial = timezone.localdate()
        if user is not None:
            self.fields["bucket"].queryset = Bucket.objects.filter(
                user=user, archived_at__isnull=True
            )
