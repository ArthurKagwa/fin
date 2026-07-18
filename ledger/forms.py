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


class IncomeEntryForm(forms.Form):
    """US-04/US-21: one form; fields activate by kind (FR-22).

    kind=other  -> amount_minor required (single figure, unchanged flow)
    kind=paycheque -> gross_minor required; take-home derived server-side
    """

    kind = forms.ChoiceField(
        choices=IncomeEvent.Kind.choices,
        initial=IncomeEvent.Kind.OTHER,
        widget=forms.RadioSelect,
    )
    amount_minor = forms.IntegerField(
        min_value=1, required=False, label="Amount (minor units)"
    )
    gross_minor = forms.IntegerField(
        min_value=1, required=False, label="Gross (minor units)"
    )
    occurred_on = forms.DateField(
        widget=forms.DateInput(attrs={"type": "date"}), initial=timezone.localdate
    )
    source = forms.CharField(max_length=120)
    note = forms.CharField(required=False, widget=forms.Textarea(attrs={"rows": 2}))

    def clean(self):
        data = super().clean()
        kind = data.get("kind")
        if kind == IncomeEvent.Kind.OTHER and not data.get("amount_minor"):
            self.add_error("amount_minor", "Required for non-paycheque income.")
        if kind == IncomeEvent.Kind.PAYCHEQUE and not data.get("gross_minor"):
            self.add_error("gross_minor", "Required for a paycheque.")
        return data


class DeductionLineForm(forms.Form):
    label = forms.CharField(max_length=80, required=False)
    amount_minor = forms.IntegerField(min_value=1, required=False, label="Amount")

    def clean(self):
        data = super().clean()
        if bool(data.get("label")) != bool(data.get("amount_minor")):
            raise forms.ValidationError("A deduction needs both a label and an amount.")
        return data


DeductionFormSet = forms.formset_factory(DeductionLineForm, extra=6)


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
