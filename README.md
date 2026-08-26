# B2B Payment Platform

A payment platform backend for B2B eCommerce merchants: create orders, initiate payments against them, and receive
asynchronous payment-provider notifications via webhook — built to the standard of "this will eventually handle real
financial transactions," not just "it runs." There is no real external payment gateway; a self-contained mock
provider (`MockPaymentProvider`) stands in for one, simulating a genuine async webhook round trip with real HMAC
signatures and no shortcuts around the verification path a real provider's webhook would have to pass.

## Stack

Ruby 4.0, Rails 8.1, PostgreSQL, Solid Queue (background jobs), RSpec + FactoryBot. No JavaScript framework — the
dashboard is server-rendered ERB with Turbo for the couple of places it's useful.

## Setup

```bash
bin/setup          # bundle install, db:prepare (creates + migrates + seeds dev), clears logs/tmp
bin/dev            # starts the Rails server on http://localhost:3000
```

`bin/setup` seeds the development database automatically as part of `db:prepare`. To (re-)seed explicitly:

```bash
bin/rails db:seed
```

Seeding is idempotent — safe to run repeatedly — and prints a merchant API bearer token the **first** time it
creates one (only shown once, since only its digest is ever persisted). If you've already seeded and lost the
token, create a fresh one:

```bash
bin/rails runner 'puts Merchant.find_by!(name: "Acme Test Merchant").api_credentials.create!(name: "New Key").token'
```

**Dashboard login:** `demo@example.com` / `password123` at `http://localhost:3000/login`.

## Running tests

```bash
bundle exec rspec   # the test suite
bin/ci              # the full CI gate: setup, rubocop, bundler-audit, brakeman, importmap audit, rspec
```

`bin/ci` is what actually runs in GitHub Actions on every push/PR — if it's green locally, CI will be green.

## API reference

All `/api/v1/*` endpoints require `Authorization: Bearer <token>` and return JSON. Every response follows one error
shape: `{ "error": "<message>" }`, with an additional `"details": [...]` array for validation failures (422).
Endpoints are scoped strictly to the authenticated merchant — a valid token from one merchant can never see or act
on another merchant's orders/payments; asking for one returns a plain `404`, not a `403`, so a client can't even
distinguish "not yours" from "doesn't exist."

Set a token once for the examples below:

```bash
export TOKEN=sk_...   # from db:seed output, or the runner snippet above
```

#### Create an order

```bash
curl -s -X POST http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"order":{"amount_cents":5000,"currency":"usd","customer_email":"buyer@example.com","customer_name":"Buyer Co"}}'
```

`amount_cents` is always an integer (never a float/decimal) and must be positive. `status` is not a client-settable
field — orders always start `pending`.

#### List / fetch orders

```bash
curl -s http://localhost:3000/api/v1/orders -H "Authorization: Bearer $TOKEN"
curl -s "http://localhost:3000/api/v1/orders?page=1&per_page=25" -H "Authorization: Bearer $TOKEN"
curl -s http://localhost:3000/api/v1/orders/ord_xxxxx -H "Authorization: Bearer $TOKEN"
```

`per_page` defaults to 25 and is capped at 100 server-side regardless of what's requested.

#### Initiate a payment

```bash
curl -s -X POST http://localhost:3000/api/v1/orders/ord_xxxxx/payments \
  -H "Authorization: Bearer $TOKEN" -H "Idempotency-Key: $(uuidgen)"
```

`Idempotency-Key` is **required** (400 without it). Replaying the same key returns the original payment (`200`)
instead of creating a duplicate (`201` on first creation) — safe to retry on a network timeout without risking a
double charge. The order moves from `pending` to `awaiting_payment`; a mock charge is kicked off asynchronously
(a real 2-second delay, then a genuinely HMAC-signed webhook comes back through the same code path a real provider's
webhook would). Poll for the result:

```bash
curl -s http://localhost:3000/api/v1/payments/pay_xxxxx -H "Authorization: Bearer $TOKEN"
```

**Triggering success vs. failure on demand:** the mock provider's outcome is deterministic, not random — an
`amount_cents` ending in `99` (e.g. `1099` / $10.99) always declines; everything else succeeds. A declined payment
leaves the order `awaiting_payment` (retryable with a fresh Idempotency-Key), not a terminal failure state.

## Webhook endpoint

`POST /webhooks/payment_provider` is how `MockPaymentProvider` (or, in a real deployment, an actual gateway) reports
a final payment status back to us. It is not bearer-token authenticated — a public POST endpoint can't require a
merchant's own credential — so it's authenticated instead by a signed header, and rate-limited (60 req/min/IP) since
it's a public, unauthenticated-by-session target:

```
X-Webhook-Signature: t=<unix timestamp>,v1=<hex hmac-sha256>
```

where the HMAC covers `"<timestamp>.<raw request body>"`, keyed by `MOCK_PROVIDER_WEBHOOK_SECRET` (falls back to a
fixed insecure value in development/test; **required** in production — the app refuses to boot without it). A
signature older than 5 minutes is rejected even if otherwise valid. Redelivery of the same `id` is a safe no-op,
checked at the database level via a unique index, not just an application-level guard.

You will not normally need to call this by hand — `MockPaymentProvider` does it for you after every payment
initiation — but to construct a valid request manually (replace `pay_xxxxx` with a real payment reference first):

```bash
eval "$(bin/rails runner '
  payload = { id: "evt_manual_1", type: "payment.succeeded",
              data: { payment_reference: "pay_xxxxx", provider_reference: "manual_test" } }.to_json
  puts "BODY=#{payload.inspect}"
  puts "SIGNATURE=#{Webhooks::SignatureVerifier.header_for(payload).inspect}"
')"

curl -s -X POST http://localhost:3000/webhooks/payment_provider \
  -H "Content-Type: application/json" -H "X-Webhook-Signature: $SIGNATURE" -d "$BODY"
```

## Dashboard

Server-rendered pages at `/dashboard/orders` (session login required, `/login`) — order list with each order's
latest payment status, an order detail page with full payment + status history, and an "Initiate Payment" button
that calls the exact same `Payments::Initiator` service the API uses. Every request is scoped through
`current_merchant`, with the same cross-merchant `404` guarantee as the API.

## Design decisions worth knowing about

- **Money is always an integer** (`amount_cents`), never a float, everywhere from the database up. Currency is a
  3-letter code, validated and normalized to uppercase.
- **State transitions are hand-rolled, not a gem** (`Payment#mark_succeeded!` / `#mark_failed!` / `#mark_processing!`
  in `app/models/payment.rb`). Each is wrapped in `with_lock`, is a no-op if the payment already reached (or passed)
  that state, and raises `Payment::InvalidTransition` on a genuine contradiction (e.g. "succeeded" arriving for an
  already-failed payment) rather than silently overwriting a terminal outcome.
- **Two independent auth mechanisms**: dashboard `User`s log in with a session cookie (`has_secure_password`);
  machine clients use a bearer-token `ApiCredential` whose raw value is shown exactly once and stored only as a
  SHA-256 digest.
- **No partial payments or refunds** — a `Payment` must exactly match its `Order`'s amount and currency. This is a
  deliberate scope simplification, not an oversight.
- **Orders never auto-transition to a terminal `failed` state** on a declined payment. A card decline is expected
  to be retried, so the order stays `awaiting_payment` and a new payment attempt (new Idempotency-Key) is allowed.
  `cancelled`/`failed` order statuses exist for a future manual/admin action, not implemented here.
- **The mock provider never makes a real network call.** `MockPaymentProvider` schedules a delayed job that builds a
  genuinely signed payload and hands it to `Webhooks::PaymentProviderProcessor` — the exact same object the public
  webhook controller calls — in-process. This exercises a real verify → dedupe → lock → transition path end-to-end
  without any of the flakiness a real HTTP loopback would add to the test suite.
- **`default_scope` is avoided everywhere** in favor of explicit `Model.for_merchant(merchant)` scopes /
  `current_merchant.orders.find_by!(...)` — a hidden, accidentally-bypassable global scope is exactly the kind of
  thing that causes a real cross-tenant data leak.

See `app/models/payment.rb`, `app/services/payments/initiator.rb`, `app/services/webhooks/signature_verifier.rb`,
and `app/controllers/webhooks/payment_provider_controller.rb` for the parts of the system with the most correctness
and security weight.
