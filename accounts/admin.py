from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


@admin.register(User)
class FinTrackUserAdmin(UserAdmin):
    """US-18: minimal ops — search by email, see plan, disable accounts."""

    list_display = ("email", "plan", "trial_ends_at", "currency", "disabled_at")
    list_filter = ("plan",)
    search_fields = ("email",)
    ordering = ("email",)
    fieldsets = UserAdmin.fieldsets + (
        (
            "FinTrack",
            {
                "fields": (
                    "currency",
                    "timezone",
                    "plan",
                    "trial_ends_at",
                    "email_verified_at",
                    "reminder_time",
                    "disabled_at",
                    "deletion_requested_at",
                )
            },
        ),
    )
