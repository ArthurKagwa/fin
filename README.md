# FinTrack

Personal finance tracker: allocate incoming money into buckets, log expenses
daily, track recurring payments. Spec pack in `docs/` (PRD → user stories →
system spec → design spec, plus ADR-001 for the stack choice).

## Stack

Django 5 · PostgreSQL in production (SQLite for dev) · server-rendered PWA.
See `docs/adr-001-stack.md`.

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

## Layout

- `accounts/` — custom user (currency, timezone, plan, trial), tenancy base model
- `ledger/` — income, buckets, allocations, expenses; invariants in `services.py`
- `recurring/` — recurring payments, rate periods (amount history), occurrences
- `templates/`, `static/` — server-rendered PWA shell
- `docs/` — spec pack + ADRs

## Conventions

- Money is integer minor units everywhere; balances are derived, never stored (NFR-09).
- Every tenant-owned query filters by `user`; cross-tenant lookups 404 (US-02).
- Domain invariants live in `services.py` modules, not views or templates.

## Tests

```bash
python manage.py test
```
