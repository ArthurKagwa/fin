from django.contrib import admin

from .models import Occurrence, RatePeriod, RecurringPayment


class RatePeriodInline(admin.TabularInline):
    model = RatePeriod
    extra = 0


@admin.register(RecurringPayment)
class RecurringPaymentAdmin(admin.ModelAdmin):
    list_display = ("user", "name", "frequency", "start_on", "end_on")
    search_fields = ("user__email", "name")
    inlines = [RatePeriodInline]


@admin.register(Occurrence)
class OccurrenceAdmin(admin.ModelAdmin):
    list_display = ("user", "recurring_payment", "due_on", "expected_minor", "status")
    list_filter = ("status",)
