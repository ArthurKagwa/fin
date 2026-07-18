"""Smoke tests for scaffold invariants (US-02, US-06, NFR-09, FR-21)."""

from datetime import date

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from .models import Bucket, Expense, IncomeEvent
from .services import (
    earnings_summary,
    prefill_deductions,
    save_paycheque,
    set_allocations,
    unallocated_total_minor,
)

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
            {
                "kind": "other",
                "amount_minor": 1000,
                "occurred_on": date.today(),
                "source": "gig",
                "note": "",
                "form-TOTAL_FORMS": "0",
                "form-INITIAL_FORMS": "0",
            },
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


class PaychequeTests(TestCase):
    """US-21/22/23: gross vs take-home."""

    def setUp(self):
        self.user = make_user("pay@x.com")

    def cheque(self, gross=1_000_000, deds=None, source="Acme"):
        return save_paycheque(
            self.user,
            gross_minor=gross,
            occurred_on=date.today(),
            source=source,
            deductions=deds
            if deds is not None
            else [
                {"label": "PAYE", "amount_minor": 200_000},
                {"label": "NSSF", "amount_minor": 50_000},
            ],
        )

    def test_takehome_is_derived(self):
        """US-21 AC-1: amount_minor = gross − Σ deductions."""
        income = self.cheque()
        self.assertEqual(income.amount_minor, 750_000)
        self.assertEqual(income.kind, IncomeEvent.Kind.PAYCHEQUE)

    def test_over_deduction_blocked(self):
        """US-21 AC-2."""
        with self.assertRaises(ValidationError):
            self.cheque(gross=100, deds=[{"label": "PAYE", "amount_minor": 200}])

    def test_edit_below_allocated_blocked(self):
        """US-21 AC-4: shrinking take-home under existing allocations fails."""
        income = self.cheque()
        rent = Bucket.objects.create(user=self.user, name="Rent")
        set_allocations(income, [{"bucket": rent, "amount_minor": 700_000}])
        with self.assertRaises(ValidationError):
            save_paycheque(
                self.user,
                gross_minor=1_000_000,
                occurred_on=date.today(),
                source="Acme",
                deductions=[{"label": "PAYE", "amount_minor": 400_000}],
                instance=income,
            )

    def test_prefill_from_last_same_source(self):
        """US-22 AC-1/2: same source prefills; unknown source is empty."""
        self.cheque()
        lines = prefill_deductions(self.user, "acme")
        self.assertEqual([l["label"] for l in lines], ["PAYE", "NSSF"])
        self.assertEqual(prefill_deductions(self.user, "Nowhere Inc"), [])

    def test_earnings_summary(self):
        """US-23: totals, rate, and n/a when no paycheques."""
        self.cheque()
        IncomeEvent.objects.create(
            user=self.user, amount_minor=30_000, occurred_on=date.today(), source="gift"
        )
        s = earnings_summary(self.user)
        self.assertEqual(s["month_totals"]["gross"], 1_000_000)
        self.assertEqual(s["month_totals"]["takehome"], 750_000)
        self.assertEqual(s["month_totals"]["deductions"], 250_000)
        self.assertEqual(s["month_totals"]["rate_pct"], 25.0)
        self.assertEqual(s["month_totals"]["other_income"], 30_000)

        empty = earnings_summary(make_user("empty@x.com"))
        self.assertIsNone(empty["month_totals"]["rate_pct"])

    def test_paycheque_view_roundtrip(self):
        """One dynamic form: kind=paycheque branch → redirect to allocation."""
        self.client.force_login(self.user)
        data = {
            "kind": "paycheque",
            "gross_minor": 500_000,
            "occurred_on": date.today(),
            "source": "Acme",
            "note": "",
            "form-TOTAL_FORMS": "2",
            "form-INITIAL_FORMS": "0",
            "form-0-label": "PAYE",
            "form-0-amount_minor": "100000",
            "form-1-label": "",
            "form-1-amount_minor": "",
        }
        r = self.client.post("/income/", data)
        income = IncomeEvent.objects.get(user=self.user)
        self.assertRedirects(r, f"/income/{income.pk}/allocate/")
        self.assertEqual(income.amount_minor, 400_000)

    def test_earnings_view_renders(self):
        self.client.force_login(self.user)
        self.assertEqual(self.client.get("/earnings/").status_code, 200)
        self.assertEqual(self.client.get("/earnings/?month=2026-06").status_code, 200)


class TrialTests(TestCase):
    def test_new_user_starts_on_trial_with_full_access(self):
        """US-17 AC-1: signup starts a 3-month full-access trial."""
        u = make_user("t@x.com")
        self.assertEqual(u.plan, User.Plan.TRIAL)
        self.assertTrue(u.has_full_access)
