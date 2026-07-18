from django.contrib import admin

from .models import Allocation, Bucket, Deduction, Expense, IncomeEvent


class DeductionInline(admin.TabularInline):
    model = Deduction
    extra = 0


@admin.register(IncomeEvent)
class IncomeEventAdmin(admin.ModelAdmin):
    list_display = ("user", "occurred_on", "kind", "gross_minor", "amount_minor", "source")
    list_filter = ("kind",)
    search_fields = ("user__email", "source")
    inlines = [DeductionInline]


@admin.register(Bucket)
class BucketAdmin(admin.ModelAdmin):
    list_display = ("user", "name", "planned_minor", "goal_minor", "archived_at")
    search_fields = ("user__email", "name")


@admin.register(Allocation)
class AllocationAdmin(admin.ModelAdmin):
    list_display = ("user", "income_event", "bucket", "amount_minor")


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ("user", "occurred_on", "bucket", "amount_minor", "deleted_at")
    search_fields = ("user__email", "payee")
