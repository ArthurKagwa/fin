"""Recurring payments: definitions, amount history, generated occurrences.

Traces: FR-09/10/11, US-09/10/11 (docs/03-system-spec.md §2).
"""

from django.core.validators import MinValueValidator
from django.db import models

from accounts.models import OwnedModel


class RecurringPayment(OwnedModel):
    """US-09: a fixed obligation with frequency and lifespan."""

    class Frequency(models.TextChoices):
        DAILY = "daily"
        WEEKLY = "weekly"
        BIWEEKLY = "biweekly"
        MONTHLY = "monthly"
        YEARLY = "yearly"
        CUSTOM = "custom"

    name = models.CharField(max_length=120)
    bucket = models.ForeignKey(
        "ledger.Bucket", on_delete=models.PROTECT, related_name="recurring_payments"
    )
    frequency = models.CharField(max_length=10, choices=Frequency.choices)
    interval_days = models.PositiveIntegerField(
        null=True, blank=True, validators=[MinValueValidator(1)]
    )  # required iff frequency == custom (validated in clean())
    start_on = models.DateField()
    end_on = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ["name"]
        constraints = [
            models.CheckConstraint(
                check=models.Q(end_on__isnull=True)
                | models.Q(end_on__gte=models.F("start_on")),
                name="recurring_end_after_start",
            ),
            models.CheckConstraint(
                check=~models.Q(frequency="custom")
                | models.Q(interval_days__isnull=False),
                name="recurring_custom_requires_interval",
            ),
        ]

    def __str__(self):
        return self.name

    def current_amount_minor(self):
        """Amount from the rate period covering today (US-10)."""
        from django.utils import timezone

        period = (
            self.rate_periods.filter(effective_from__lte=timezone.localdate())
            .order_by("-effective_from")
            .first()
        )
        return period.amount_minor if period else None


class RatePeriod(OwnedModel):
    """US-10: amount valid from a date; history is never overwritten.

    Postgres migration adds an exclusion constraint against overlapping
    periods per payment; app-level validation covers SQLite dev.
    """

    recurring_payment = models.ForeignKey(
        RecurringPayment, on_delete=models.CASCADE, related_name="rate_periods"
    )
    amount_minor = models.BigIntegerField(validators=[MinValueValidator(1)])
    effective_from = models.DateField()

    class Meta:
        ordering = ["effective_from"]
        constraints = [
            models.UniqueConstraint(
                fields=["recurring_payment", "effective_from"],
                name="unique_rate_period_start",
            )
        ]


class Occurrence(OwnedModel):
    """US-11: one expected charge, materialized 60 days ahead by the
    generation job. Confirmed -> creates an Expense; skipped -> no charge;
    linked -> points at a manually logged Expense instead.
    """

    class Status(models.TextChoices):
        PENDING = "pending"
        CONFIRMED = "confirmed"
        SKIPPED = "skipped"
        LINKED = "linked"

    recurring_payment = models.ForeignKey(
        RecurringPayment, on_delete=models.CASCADE, related_name="occurrences"
    )
    due_on = models.DateField()
    expected_minor = models.BigIntegerField(validators=[MinValueValidator(1)])
    status = models.CharField(
        max_length=10, choices=Status.choices, default=Status.PENDING
    )

    class Meta:
        ordering = ["due_on"]
        indexes = [models.Index(fields=["user", "status", "due_on"])]
        constraints = [
            models.UniqueConstraint(
                fields=["recurring_payment", "due_on"],
                name="unique_occurrence_per_due_date",
            )
        ]
