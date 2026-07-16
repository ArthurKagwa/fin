"""Accounts: custom user with tenancy, currency, plan and trial state.

Traces: FR-01/02/03/16/18, US-01/02/03/17 (docs/01-prd.md, 02-user-stories.md).
"""

import uuid
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


def default_trial_end():
    return timezone.now() + timedelta(days=settings.TRIAL_DAYS)


class User(AbstractUser):
    class Plan(models.TextChoices):
        TRIAL = "trial"
        FREE = "free"
        PAID = "paid"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)

    # FR-03: locked after first money entry (enforced in services, see ledger).
    currency = models.CharField(max_length=3, default="USD")
    timezone = models.CharField(max_length=64, default="UTC")

    email_verified_at = models.DateTimeField(null=True, blank=True)

    # US-17: app-managed trial (ADR-001) — sweep flips trial -> free at expiry.
    plan = models.CharField(max_length=8, choices=Plan.choices, default=Plan.TRIAL)
    trial_ends_at = models.DateTimeField(default=default_trial_end)

    # US-12: daily reminder time in the user's timezone; null = off.
    reminder_time = models.TimeField(null=True, blank=True)

    disabled_at = models.DateTimeField(null=True, blank=True)
    deletion_requested_at = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username"]

    def __str__(self):
        return self.email

    @property
    def has_full_access(self) -> bool:
        """Trial or paid users bypass free-tier gates (US-17)."""
        if self.plan == self.Plan.PAID:
            return True
        if self.plan == self.Plan.TRIAL and self.trial_ends_at > timezone.now():
            return True
        return False


class OwnedModel(models.Model):
    """Base for all tenant-owned rows (FR-02).

    Every query MUST filter by user; views use the owned() helper, never
    objects.get(pk=...) directly. Cross-tenant lookups 404 (US-02).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, editable=False
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
