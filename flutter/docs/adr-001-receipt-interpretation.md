# ADR pack — v1 income/expense logger with receipt & screenshot interpretation

**Status:** Proposed
**Date:** 2026-07-23
**Deciders:** product owner + implementing dev

---

## Assumptions (flag any that are wrong — they change the answer)

| # | Assumption | If wrong |
|---|---|---|
| A1 | "icone" = **income**; v1 logs income and expenses | — |
| A2 | Single user per account, one device typical, Android only | Multi-device pushes hard toward Firestore |
| A3 | "Screenshot" = payment/bank/UPI confirmation screens, i.e. crisp digital text | If it means arbitrary web pages, extraction scope widens a lot |
| A4 | Consumer app, personal finance — not accounting/tax-grade | Tax-grade means audit trail, image retention, immutability |
| A5 | v1 traffic is hundreds of users, not tens of thousands | Cost analysis below flips at ~10k users |
| A6 | No bank/Plaid integration in v1 | Bank feeds would make manual capture near-obsolete |

---

# ADR-001: Where receipt and screenshot interpretation runs

## Context

The app must turn a photo of a receipt or a screenshot of a payment confirmation into a structured transaction: amount, currency, date, merchant, direction, category.

Two separable problems, routinely conflated:

1. **Text extraction** (pixels → characters). Near-solved. On-device ML Kit is excellent on crisp screenshots, mediocre on crumpled thermal receipts in bad light.
2. **Semantic extraction** (characters → *which* number is the total, not the subtotal, tax, change tendered, or loyalty points balance). This is the actual problem, and it is where heuristics fail.

Receipts have no schema. Total may be labelled TOTAL, AMOUNT DUE, BALANCE, or nothing. Currency may be symbol, code, or absent. Dates are locale-ambiguous (03/04/26). A hand-written regex layer will hit maybe 60–70% on the head of the distribution and fall apart on the tail — and a "smart" feature that is wrong 30% of the time is worse than no feature, because users stop trusting it and revert to typing.

Hard constraint: **the API key cannot ship in the client.** APKs decompile. This is not negotiable and it eliminates any design where Flutter calls the model directly.

## Decision

**Cloud multimodal LLM behind a Firebase callable function, with mandatory human review before any transaction is written.** Inference is brokered through OpenRouter — see ADR-004.

Client downscales the image and sends it to a callable; the function calls a vision model with a forced-schema tool definition; the structured result pre-fills a review screen; the user confirms; only then does a transaction exist.

**On-device AI is ruled out by decision** (Options A and C below are recorded for the record, not as live candidates). The analysis already favoured cloud, so this costs little — but it does forfeit three things, and they should be forfeited knowingly:

1. **No offline capture, and no degraded fallback.** Network down means the feature is simply gone. Manual entry becomes the only path, so it must be genuinely good, not a grudging afterthought.
2. **No cheap pre-flight gate.** An on-device text-presence check would reject blurry, blank, or non-receipt images for free. Without it, every garbage capture costs a paid API call. Compensate with non-AI client-side checks — resolution floor, file-size floor, Laplacian-variance blur check — which are cheap and catch most of it.
3. **Every image leaves the device, with no local-only mode to offer privacy-sensitive users.** This is now a fixed property of the product, not a setting.

## Options considered

### Option A: On-device only (ML Kit OCR + heuristic parsing) — ❌ ruled out by decision

| Dimension | Assessment |
|---|---|
| Complexity | Medium — deceptively so; the parser is an endless tail of rules |
| Cost | Zero marginal; no backend, stays on Firebase Spark |
| Accuracy | Good on screenshots, poor on real-world receipts |
| Privacy | Best — nothing leaves the device |
| Offline | Works |

**Pros:** free, private, instant, no backend, no billing risk.
**Cons:** semantic extraction is the product and this option is weakest exactly there. Maintenance is a permanent regex treadmill. Every new merchant format is a bug report.

### Option B: Cloud multimodal LLM via callable function ✅

| Dimension | Assessment |
|---|---|
| Complexity | Medium — one function, one schema, one review screen |
| Cost | ~$0.004–0.013 per scan (see below); negligible at v1 volume |
| Accuracy | Strongest on both receipts and screenshots; handles the tail |
| Privacy | Weakest — images leave the device to a third party |
| Offline | Fails; manual entry must remain fully functional offline |

**Pros:** one implementation covers both input types and the long tail. Schema-forced output. Improves as models improve, with no client release. Structured extraction quality is not achievable any other way at this effort level.
**Cons:** requires Blaze billing, network, and a per-scan cost. Introduces a billing-abuse attack surface. PII leaves the device — a disclosure and Play Data Safety obligation.

### Option C: On-device OCR → text-only LLM — ❌ ruled out by decision

| Dimension | Assessment |
|---|---|
| Complexity | High — two failure stages, layout serialisation |
| Cost | Lower per call, but not the binding constraint |
| Accuracy | Capped by OCR quality; loses spatial layout, which carries meaning on receipts |
| Privacy | Better — text can be redacted pre-send |

**Pros:** cheaper payloads, redaction possible, degrades gracefully.
**Cons:** you pay a large complexity tax to optimise a cost that isn't hurting you. OCR errors compound invisibly. Column alignment — how you tell a total from a line item — is destroyed by naive serialisation.

### Option D: Purpose-built receipt API (Veryfi, Mindee, Taggun)

| Dimension | Assessment |
|---|---|
| Complexity | Low — best-in-class SDK for receipts |
| Cost | Higher per scan; per-vendor pricing |
| Accuracy | Excellent on receipts, **poor/undefined on arbitrary screenshots** |

**Pros:** highest receipt accuracy for least work; line-item extraction included.
**Cons:** you asked for screenshots too, and these tools are trained on paper documents. You'd need Option B anyway for the second half, so you'd run two vendors.

## Trade-off analysis

**A vs B is the real decision, and it is a bet on where the product's value sits.** If the app's value is a clean ledger, choose A and treat the camera as convenience. If the value is "never type a transaction again," A cannot deliver it and choosing it produces a demo, not a product. Your framing ("intelligent interpretation capability") says B.

**Cost is not the constraint, and it is worth killing that worry early.** Grounded in current published figures: <cite index="1-1">Claude bills images in 28×28-pixel patches, so an image costs ⌈width/28⌉ × ⌈height/28⌉ visual tokens</cite>. A receipt downscaled to 1176×1568 is ~2,350 image tokens. With prompt and structured output, one scan lands around **1.3¢ on Sonnet 4.6 ($3/$15 per million) or 0.4¢ on Haiku 4.5 ($1/$5)**. At 30 scans/user/month: 100 users ≈ $12–39/month. That is noise. It becomes material near 10k users (~$1.2–3.9k/month), which is a problem you should be happy to have and can attack then via Haiku, aggressive downscaling, and caching the system prompt.

**Therefore: optimise v1 for accuracy, not for token cost.** Default to the stronger model; measure before downgrading. The premature Haiku choice is the classic error here — it saves ~$27/month at v1 scale in exchange for the failure mode that kills the product.

**Downscaling is the one preprocessing lever that matters,** and it should be adaptive, not fixed. <cite index="6-1">Resizing to 1568px on the long edge typically cuts cost substantially with no accuracy loss on text-heavy images</cite>, and oversized uploads are downscaled server-side anyway — you pay upload bandwidth and latency for pixels the model never sees. Screenshots are crisp synthetic text and survive ~1024px; camera photos of thermal receipts need the full 1568px. Two profiles, chosen by source.

## Consequences

**Easier:** one code path handles both input types; extraction quality improves without client releases; adding fields (tip, tax, line items) is a schema edit, not a parser rewrite.

**Harder:**
- Firebase moves to **Blaze**. Cloud Functions cannot make outbound calls on the free tier. Budget alerts become mandatory, not optional.
- Capture requires network. Manual entry must work fully offline, and the UI must say plainly when capture is unavailable rather than failing opaquely.
- **PII leaves the device.** Payment screenshots contain balances, partial card numbers, counterparty names. This needs a privacy policy, a Play Console Data Safety declaration, and an in-app disclosure at first capture. Do not discover this at review time.
- **A callable that spends money on every invocation is a billing attack surface.** Enforce App Check, a per-user daily scan quota checked inside the function before the model call, a hard image-size cap, and a Cloud Billing budget alert. An unauthenticated or unprotected endpoint here will eventually be found and drained.

**Revisit when:** monthly spend exceeds ~$200 (evaluate Haiku + prompt caching), or receipt accuracy plateaus below acceptable (evaluate Option D for the receipt path only, keeping B for screenshots).

---

# ADR-002: Never auto-commit an extracted transaction

**Status:** Proposed — and the cheapest high-value decision in this pack.

**Context.** Vision models produce confident, well-formed, wrong numbers. The documented defence is <cite index="6-1">confidence-gated human review for any field used in money decisions</cite>. A silently wrong ledger is worse than an empty one: the user finds out weeks later, can't tell which entries are corrupt, and abandons the app.

**Decision.** Extraction pre-fills a **review screen**, never writes directly. Amount, date, and merchant are always editable. Fields the model was unsure of are visually flagged. The user confirms; confirmation is the only path that creates a transaction.

**Consequence.** This costs you one screen and reframes the feature from "magic that must be perfect" to "typing assistance that saves 20 seconds" — a bar you can actually clear. It also converts every correction into free labelled evaluation data. Log the pre-edit and post-edit values (amount and date only, not the image) to measure real field-level accuracy instead of guessing at it.

Also mandated here: **prompt the model to return values exactly as printed, without translating or normalising**, and do normalisation in your own code where it is testable.

---

# ADR-003: Firestore vs local-first SQLite

**Context.** ADR-001 already commits you to Firebase for Functions, Auth, and App Check. Whether *transaction data* also belongs in Firestore is a separate question, and the default answer deserves challenging.

A solo expense ledger is small, single-writer, and read constantly by exactly one client. That is close to the ideal case for local SQLite (Drift) — zero latency, zero read cost, full offline function, no rules to get wrong. Firestore's core value is realtime multi-device sync, which this workload barely exercises.

**Decision: Firestore anyway, for v1** — but on marginal-cost grounds, not because it is the better data store here. The Firebase dependency exists regardless; adding one more product is cheaper than running and reconciling two persistence models, and it gives you free device-loss recovery, which for financial data users care about more than they say.

**Counter-argument, stated honestly:** if v1 has no auth and no sync requirement, Drift is faster, free, offline by default, and has no security-rules failure mode. If A2 is wrong and this app is genuinely single-device, revisit this — it is the one decision here that gets more expensive to reverse the longer you wait.

**Non-negotiable regardless of store:** money is stored as **integer minor units** (`amountMinor: 1250`, `currency: "USD"`), never floating point. Floats in a ledger produce cent-level drift in sums that is embarrassing to explain and annoying to migrate away from later.

---

# ADR-004: OpenRouter as the inference gateway

**Status:** Accepted (decided)

## Context

ADR-001 commits to a cloud vision model. This decides how the function reaches one.

## Why this is the right call *for this product specifically*

Action item #2 in this pack says: benchmark candidate models on real receipts before building the UI, because extraction accuracy is unknown in advance and the product thesis depends on it. Against a single provider, that benchmark costs N integrations and N billing relationships. Through OpenRouter it is a string change in a config file.

That is the real argument, and it is strong: **you are architecting for a decision you cannot yet make correctly.** A model-swap-cheap design is worth a lot when the right model is an open empirical question. Secondary benefits — one key, one bill, automatic failover — are real but minor next to this.

## What it costs you, concretely

### 1. Schema enforcement gets weaker, and this is the sharpest issue

ADR-001 depends on forced-schema output. Through OpenRouter that guarantee is softer than it looks. <cite index="13-1">OpenRouter normalises the API surface, but structured-output behaviour still depends on model and provider support.</cite> Worse, support is listed **per model** while routing happens **per provider**: <cite index="10-1">a model can be listed as supporting structured outputs because one provider out of five supports it, while the other four only support tools</cite>.

The failure mode is nasty because it is intermittent — identical requests to the same model name can be served by different providers with different enforcement. You will see it as a rare, unreproducible parse failure in production, not as a clean error in dev.

**Mitigations, all of which belong in v1:**
- Pin providers explicitly with `provider.only`, and set `allow_fallbacks: false` on the extraction call — <cite index="20-1">with `allow_fallbacks` set to false, OpenRouter returns an error instead of routing to a provider outside your list</cite>. An error you can retry beats a silent schema break.
- Prefer **forced tool calling** over `response_format` json_schema where they diverge; <cite index="10-1">forced tool calling has broader provider compatibility and lets the request load-balance across more providers</cite>.
- **Validate the parsed object server-side regardless.** <cite index="13-1">The safe production workflow validates the returned object before using it.</cite> Never trust the shape because the schema was requested.
- Retry once on schema-validation failure, then surface a clean "couldn't read this — enter manually" rather than a spinner.
- Any fallback model must satisfy the same schema — <cite index="13-1">a fallback that answers well but breaks the schema still breaks the application</cite>.

### 2. Privacy now crosses two administrative boundaries

You are sending screenshots containing bank balances and counterparty names. <cite index="19-1">Every OpenRouter request crosses two administrative boundaries — your client to OpenRouter, and OpenRouter to the downstream provider — and the retention and training defaults that apply are the union of both parties' policies.</cite>

Non-negotiable settings for a financial app:

| Setting | Value | Why |
|---|---|---|
| Prompt logging / 1% discount | **OFF** | <cite index="24-1">Enabling prompt logging grants OpenRouter an irrevocable right to commercial use of those inputs and outputs.</cite> Disqualifying at any discount |
| `provider.data_collection` | `deny` | <cite index="20-1">Blocks providers that store or train on inputs</cite> |
| `provider.zdr` | `true` | <cite index="20-1">Restricts routing to Zero Data Retention endpoints</cite> |
| Paid/free endpoints that may train | **OFF** | Account-level; free endpoints are the risky ones |

**Set these in the request body, not only in the dashboard.** Account defaults exist, but a dashboard toggle is invisible to code review and someone will eventually flip it during debugging and forget. In the request body they are version-controlled, reviewable, and diffable. Belt and braces: set both.

Caveat worth knowing: <cite index="25-1">OpenRouter treats in-memory prompt caching as compatible with ZDR</cite>, so "zero retention" is not "zero copies anywhere." If A4 turns out to be wrong and this is a regulated/tax-grade product, that distinction will matter.

### 3. Reliability failure mode moves rather than disappearing

OpenRouter sells resilience through failover, but you have introduced a dependency whose outage takes down *every* model at once. Net availability is probably still better than a single provider — but the correlated-failure risk is new. For v1, accept it: capture degrades to manual entry, which is acceptable. Revisit if capture becomes the primary input path.

### 4. Cost predictability drops

Per-scan cost stays negligible at v1 volume, so this is a footnote, not an objection. But note two things: OpenRouter passes through inference pricing and takes a platform fee on credit purchases (verify the current rate at signup — do not budget from memory), and **image token accounting differs by model.** Some price per-pixel-patch, others charge a flat per-image count regardless of resolution. That means the downscaling optimisation in ADR-001 is model-dependent: aggressive downscaling that halves cost on one model may save only bandwidth on another. Re-measure after you pick a model; don't assume the ADR-001 math carries over.

### 5. Billing-abuse mitigation changes shape

OpenRouter credits are prepaid. That is an advantage — **keep a deliberately low balance with a capped auto-topup rather than a large float.** A drained balance fails closed and costs you a known maximum, which is strictly better than an uncapped provider bill. This does not replace App Check or per-user quotas; it bounds the worst case if both fail.

### 6. Model selection: pinned, but configurable — resolves Q-06

Decision: **exactly one model live at a time, no dynamic per-request routing** — that keeps accuracy attributable and the schema-enforcement risk in §1 bounded to a single, known provider path. But the pin itself is **data, not code**: store it as one document, e.g. `config/inference { model: "anthropic/claude-sonnet-4-6", provider: "anthropic", updatedAt, updatedBy }`, read by the function per request with a short in-memory cache (~60s) rather than baked into an environment variable.

That specific shape is chosen over the two obvious alternatives, and it's worth seeing why:

- **Hardcoded in function source** — safest, fully code-reviewed, but a model swap means a redeploy. Fine at v1's pace of change, wrong once you're swapping weekly during the benchmark phase.
- **Client-supplied model parameter** — do not do this. Letting the client pick the model turns "configurable" into "user-controlled spend," and a modified or reverse-engineered client could request the most expensive model on every call. The pin must be decided server-side, never accepted as client input.
- **Firestore config doc (chosen)** — swappable without a redeploy, which is what "configurable" should mean here, and still auditable (`updatedBy`/`updatedAt` on the doc, admin-only write rule) — it's a data change with a paper trail, not a silent toggle.

Two guards this needs to actually be safe, not just convenient:
- **Validate against a server-side allowlist of models known to be vision-capable and schema/tool-compatible on the pinned provider** — this doc must not be able to select something that fails §1 silently. An unvalidated free-text model string is a footgun with the same shape as the client-supplied-model mistake above, just one step removed.
- **Log the model name on every parse** (already in the metrics action item) — a config change and an accuracy regression need to be correlatable after the fact, or "configurable" just means "untraceable when it goes wrong."

## Consequences

**Easier:** benchmarking many models is nearly free; swapping the model after launch is a config change, not a release; one key, one invoice.

**Harder:** schema guarantees need defensive validation and provider pinning; privacy posture requires explicit per-request flags and a two-party disclosure; cost modelling must be redone per candidate model.

**Revisit when:** a single model wins the benchmark decisively and stays stable for a quarter — at that point evaluate BYOK or a direct provider integration as a fallback path, keeping OpenRouter as primary.

## Action items specific to this ADR

1. [ ] Set account privacy flags **before** the first real receipt is sent — not after the benchmark
2. [ ] Put `data_collection: deny`, `zdr: true`, `only: [...]`, `allow_fallbacks: false` in the request body and code-review them
3. [ ] Store the OpenRouter key in Secret Manager, referenced by the function; never in the repo, never in the client, never in `firebase functions:config` plaintext
4. [ ] Verify image-capable + structured-output-capable providers for each benchmark candidate on the models page, per provider, not per model name
5. [ ] Create the `config/inference` doc with an admin-only write rule and a server-side allowlist of validated models; wire the function to read it with a short cache instead of a hardcoded string
5. [ ] Add a schema-validation failure counter to your metrics — this is the metric that catches silent routing degradation

---

# v1 system design

## Data flow

```
 [camera] [gallery] [Android share-sheet]
        \      |      /
         v     v     v
   ┌─────────────────────────┐
   │ CaptureController        │  non-AI gate: resolution floor, blur check
   │ (Riverpod AsyncNotifier) │  downscale: screenshot→1024px, photo→1568px
   └──────────┬──────────────┘  JPEG q80, hard cap ~1.5MB
              │ callable: parseCapture({imageB64, sourceType, localeHints})
              v
   ┌─────────────────────────┐
   │ Cloud Function           │  App Check enforced
   │  1. verify auth + quota  │  per-user daily cap, checked BEFORE model call
   │  2. call OpenRouter      │  forced tool call; provider pinned;
   │                          │  zdr:true, data_collection:deny,
   │                          │  allow_fallbacks:false
   │  3. validate schema      │  reject malformed, retry once, then fail clean
   │  4. normalise            │  dates/currency in YOUR code, not the model's
   └──────────┬──────────────┘
              │            ┌──────────────┐    ┌────────────────┐
              └── via ────>│ OpenRouter   │───>│ model provider │
                           └──────────────┘    └────────────────┘
                            two trust boundaries — both in the privacy policy
              │ ParsedDraft { amountMinor, currency, occurredAt,
              │               merchant, direction, category, fieldConfidence[] }
              v
   ┌─────────────────────────┐
   │ REVIEW SCREEN (ADR-002)  │  low-confidence fields flagged
   └──────────┬──────────────┘
              │ user confirms
              v
        Firestore: users/{uid}/transactions/{id}
```

## Data model

```
users/{uid}/transactions/{txId}
  amountMinor    int        # 1250 = 12.50 — never a double
  currency       string     # ISO 4217
  direction      string     # 'income' | 'expense'
  occurredAt     timestamp  # when the money moved, not when logged
  createdAt      timestamp
  merchant       string?
  category       string     # fixed v1 enum; user-defined categories are v2
  note           string?
  source         string     # 'manual' | 'receipt' | 'screenshot'
  contentHash    string?    # sha256 of downscaled image — duplicate detection
```

`contentHash` exists because users will scan the same receipt twice. Warn on collision; don't block — a genuine repeat purchase at the same merchant for the same amount is possible.

Indexes needed on day one: `(occurredAt desc)` for the ledger; `(direction, occurredAt desc)` for filtered views.

Security rules: owner-only read/write on `users/{uid}/**`, plus immutability of `uid` and validation that `amountMinor` is an int. Write these with the first transaction feature, not later.

## Android integration

- **Share-sheet receiver is the highest-leverage UX decision for the screenshot path.** Users screenshot a payment confirmation and share it — no app switch, no gallery hunt. Register the intent filter; without it, screenshot capture is meaningfully worse than manual entry and the feature goes unused.
- Android 13+ granular media permissions; prefer the Photo Picker, which needs no permission at all.
- Camera permission requested at point of use, never at launch.

## Model contract

Force structured output via a tool/schema definition rather than parsing prose. Set `max_tokens` generously — truncated JSON is a documented failure mode and a silent one. Return an explicit `null` plus a reason for any field not present in the image; a model that must guess will guess.

---

## Explicitly out of scope for v1

Cutting these is what makes the timeline real. Say no now, in writing:

budgets · recurring transactions · multi-currency conversion · bank/Plaid feeds · CSV/PDF export · charts beyond a monthly total · user-defined categories · receipt image retention · line-item extraction · iOS · web · shared/household accounts · attachments on manual entries

**Receipt image retention** is the one worth arguing about. Discarding after parse is cheaper, simpler, and far better for privacy. Keep it only if A4 is wrong and this is tax-grade.

---

## Top risks

| Risk | Severity | Mitigation |
|---|---|---|
| Billing drain via unprotected callable | **High** | App Check, per-user quota inside the function, size cap, budget alert, low prepaid balance with capped topup |
| Extraction accuracy below usable threshold | **High** | ADR-002 review screen; benchmark on 50 real receipts *before* building the UI |
| PII in screenshots sent to **two** third parties | **High** | ZDR + data_collection deny + logging off; disclosure at first use; both parties named in privacy policy and Play Data Safety |
| Intermittent schema break from provider routing | **High** | Pin providers, `allow_fallbacks: false`, server-side validation, failure-rate metric |
| Prompt-logging discount enabled by someone | Medium | It grants irrevocable commercial-use rights — document why it stays off |
| Float money bugs | Medium | Integer minor units from commit #1 |
| Locale date ambiguity (03/04/26) | Medium | Pass device locale as a hint; surface parsed date prominently for review |
| No offline path for capture at all | Medium | Manual entry must be first-class, not a fallback UI |

## Action items

1. [ ] Confirm or correct assumptions A1–A6 — several flip decisions above
2. [ ] **Benchmark before building.** 50 real receipts + 20 screenshots against 3–4 candidate models — OpenRouter makes this cheap, so use the leverage you just bought. Measure field-level accuracy on amount/date/merchant. If amount accuracy is under ~90% on the best candidate, the product thesis needs revisiting — better to learn this in a day than a month
3. [ ] Enable Blaze + a Cloud Billing budget alert **before** the first model call; set OpenRouter privacy flags before the first *real* receipt
4. [ ] Define the extraction JSON schema; treat it as a versioned contract
5. [ ] Build manual entry end-to-end first — it is the offline fallback and the review screen's foundation
6. [ ] Write Firestore rules alongside the first write, not after
7. [ ] Draft the privacy disclosure before the first capture ships

## Open questions

- **Q-01 (blocks A1/scope):** single currency, or must v1 handle mixed-currency receipts?
- **Q-02 (blocks ADR-003):** is auth in v1 at all? No auth means no Firestore, and pushes Drift.
- **Q-03 (blocks ADR-002):** is a per-user scan quota acceptable product behaviour, and what number?
- **Q-04:** category taxonomy — who defines the fixed v1 list?
- **Q-05:** target locale(s)? Date and currency parsing is locale-dependent and this determines your benchmark set.
- ~~Q-06 (ADR-004): pin one model, or route dynamically?~~ **Resolved:** pin one model at a time, held as a server-side, admin-writable config document — not hardcoded, not client-supplied. See ADR-004 §6.
