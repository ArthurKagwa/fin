"""Ledger: income, buckets, allocations, expenses.

Money is integer minor units everywhere (NFR-09). Balances are always derived
from entry history, never stored. Traces: FR-04..08, FR-12, FR-21;
US-04..08, US-13, US-20 (docs/03-system-spec.md §2).
"""

from django.core.validators import MinValueValidator
from django.db import models

from accounts.models import OwnedModel


class IncomeEvent(OwnedModel):
    """US-04: any money in — wage, gig, gift, one-off."""

    amount_minor = models.BigIntegerField(validators=[MinValueValidator(1)])
    occurred_on = models.DateField()
    source = models.CharField(max_length=120)
    note = models.TextField(blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "occurred_on"]),
            models.Index(fields=["user", "source"]),
        ]
        ordering = ["-occurred_on", "-created_at"]

    def allocated_minor(self) -> int:
        return self.allocations.aggregate(s=models.Sum("amount_minor"))["s"] or 0

    def unallocated_minor(self) -> int:
        return self.amount_minor - self.allocated_minor()


class Bucket(OwnedModel):
    """US-05/US-20: named destination for money; optional plan and goal.

    Balance = all-time allocations - expenses, so rollover (FR-21) is inherent.
    Archive-only: hard delete is blocked when history exists.
    """

    name = models.CharField(max_length=80)
    planned_minor = models.BigIntegerField(
        null=True, blank=True, validators=[MinValueValidator(0)]
    )
    goal_minor = models.BigIntegerField(
        null=True, blank=True, validators=[MinValueValidator(1)]
    )
    archived_at = models.DateTimeField(null=True, blank=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "name"],
                condition=models.Q(archived_at__isnull=True),
                name="unique_active_bucket_name_per_user",
            )
        ]

    def __str__(self):
        return self.name

    def balance_minor(self) -> int:
        allocated = self.allocations.aggregate(s=models.Sum("amount_minor"))["s"] or 0
        spent = self.expenses.filter(deleted_at__isnull=True).aggregate(
            s=models.Sum("amount_minor")
        )["s"] or 0
        return allocated - spent


class Allocation(OwnedModel):
    """US-06: a slice of one income event assigned to one bucket.

    Invariant (service-enforced, ledger.services.set_allocations):
    sum(allocations of an income event) <= its amount_minor.
    """

    income_event = models.ForeignKey(
        IncomeEvent, on_delete=models.CASCADE, related_name="allocations"
    )
    bucket = models.ForeignKey(
        Bucket, on_delete=models.PROTECT, related_name="allocations"
    )
    amount_minor = models.BigIntegerField(validators=[MinValueValidator(1)])

    class Meta:
        indexes = [models.Index(fields=["user", "bucket"])]


class Expense(OwnedModel):
    """US-07/08: a spend against a bucket. Soft delete backs the undo window."""

    bucket = models.ForeignKey(
        Bucket, on_delete=models.PROTECT, related_name="expenses"
    )
    amount_minor = models.BigIntegerField(validators=[MinValueValidator(1)])
    occurred_on = models.DateField()
    payee = models.CharField(max_length=120, blank=True)
    note = models.TextField(blank=True)
    # Set when this expense came from confirming/linking an occurrence (US-11).
    occurrence = models.OneToOneField(
        "recurring.Occurrence",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="expense",
    )
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["user", "occurred_on"])]
        ordering = ["-occurred_on", "-created_at"]
