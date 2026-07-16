from django.contrib import admin

from .models import Allocation, Bucket, Expense, IncomeEvent


@admin.register(IncomeEvent)
class IncomeEventAdmin(admin.ModelAdmin):
    list_display = ("user", "occurred_on", "amount_minor", "source")
    search_fields = ("user__email", "source")


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
