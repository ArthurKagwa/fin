"""Smoke tests for scaffold invariants (US-02, US-06, NFR-09, FR-21)."""

from datetime import date

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from .models import Bucket, Expense, IncomeEvent
from .services import set_allocations, unallocated_total_minor

User = get_user_model()


def make_user(email):
    return User.objects.create_user(
        username=email, email=email, password="a-long-password-123"
    )


class AllocationInvariantTests(TestCase):
    def setUp(self):
        self.user = make_user("a@example.com")
        self.income = IncomeEvent.objects.create(
            user=self.user, amount_minor=300_000, occurred_on=date.today(), source="job"
        )
        self.rent = Bucket.objects.create(user=self.user, name="Rent")
        self.food = Bucket.objects.create(user=self.user, name="Food")

    def test_over_allocation_rejected(self):
        """US-06 AC-2: sum of splits may not exceed the income amount."""
        with self.assertRaises(ValidationError):
            set_allocations(
                self.income,
                [
                    {"bucket": self.rent, "amount_minor": 250_000},
                    {"bucket": self.food, "amount_minor": 100_000},
                ],
            )
        self.assertEqual(self.income.allocations.count(), 0)

    def test_partial_allocation_leaves_unallocated(self):
        """US-06 AC-3: remainder stays unallocated and is derivable."""
        set_allocations(self.income, [{"bucket": self.rent, "amount_minor": 200_000}])
        self.assertEqual(unallocated_total_minor(self.user), 100_000)

    def test_balance_derives_and_rolls_over(self):
        """NFR-09/FR-21: balance = allocations − live expenses; soft-deleted
        expenses don't count."""
        set_allocations(self.income, [{"bucket": self.rent, "amount_minor": 200_000}])
        e = Expense.objects.create(
            user=self.user,
            bucket=self.rent,
            amount_minor=50_000,
            occurred_on=date.today(),
        )
        self.assertEqual(self.rent.balance_minor(), 150_000)
        e.deleted_at = e.created_at
        e.save()
        self.assertEqual(self.rent.balance_minor(), 200_000)


class TenantIsolationTests(TestCase):
    def test_owned_rows_are_scoped_by_user(self):
        """US-02: one user's rows never appear in another's queryset."""
        a, b = make_user("a@x.com"), make_user("b@x.com")
        Bucket.objects.create(user=a, name="Rent")
        self.assertEqual(Bucket.objects.filter(user=b).count(), 0)

    def test_bucket_name_unique_per_user_not_global(self):
        a, b = make_user("a2@x.com"), make_user("b2@x.com")
        Bucket.objects.create(user=a, name="Rent")
        Bucket.objects.create(user=b, name="Rent")  # must not raise
        self.assertEqual(Bucket.objects.filter(name="Rent").count(), 2)


class ViewSmokeTests(TestCase):
    """Every navigable screen renders and the core flow round-trips."""

    def setUp(self):
        self.user = make_user("nav@x.com")
        self.client.force_login(self.user)

    def test_screens_render(self):
        for name in ["dashboard", "bucket-list", "income-list", "expense-add", "recurring-list"]:
            with self.subTest(name=name):
                self.assertEqual(self.client.get(f"/{'' if name == 'dashboard' else ''}", follow=True).status_code, 200)
        self.assertEqual(self.client.get("/buckets/").status_code, 200)
        self.assertEqual(self.client.get("/income/").status_code, 200)
        self.assertEqual(self.client.get("/expense/").status_code, 200)
        self.assertEqual(self.client.get("/recurring/").status_code, 200)

    def test_income_to_allocation_flow(self):
        bucket = Bucket.objects.create(user=self.user, name="Rent")
        r = self.client.post(
            "/income/",
            {"amount_minor": 1000, "occurred_on": date.today(), "source": "gig", "note": ""},
        )
        income = IncomeEvent.objects.get(user=self.user)
        self.assertRedirects(r, f"/income/{income.pk}/allocate/")
        r = self.client.post(f"/income/{income.pk}/allocate/", {f"bucket_{bucket.pk}": "600"})
        self.assertRedirects(r, "/")
        self.assertEqual(unallocated_total_minor(self.user), 400)

    def test_cross_tenant_allocate_404s(self):
        """US-02: another user's income event is a 404, not a form."""
        other = make_user("other@x.com")
        income = IncomeEvent.objects.create(
            user=other, amount_minor=500, occurred_on=date.today(), source="x"
        )
        self.assertEqual(
            self.client.get(f"/income/{income.pk}/allocate/").status_code, 404
        )


class TrialTests(TestCase):
    def test_new_user_starts_on_trial_with_full_access(self):
        """US-17 AC-1: signup starts a 3-month full-access trial."""
        u = make_user("t@x.com")
        self.assertEqual(u.plan, User.Plan.TRIAL)
        self.assertTrue(u.has_full_access)
