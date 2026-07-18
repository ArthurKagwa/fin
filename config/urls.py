from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.urls import path

from ledger import views as ledger_views
from recurring import views as recurring_views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("login/", auth_views.LoginView.as_view(), name="login"),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("", ledger_views.dashboard, name="dashboard"),
    path("buckets/", ledger_views.bucket_list, name="bucket-list"),
    path("buckets/<uuid:pk>/archive/", ledger_views.bucket_archive, name="bucket-archive"),
    path("income/", ledger_views.income_list, name="income-list"),
    path("income/prefill/", ledger_views.deduction_prefill, name="deduction-prefill"),
    path("income/<uuid:pk>/allocate/", ledger_views.income_allocate, name="income-allocate"),
    path("earnings/", ledger_views.earnings_report, name="earnings-report"),
    path("expense/", ledger_views.expense_add, name="expense-add"),
    path("recurring/", recurring_views.recurring_list, name="recurring-list"),
]
