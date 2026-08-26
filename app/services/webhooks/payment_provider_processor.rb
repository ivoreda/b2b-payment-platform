# The actual "accept a payment provider notification" logic, shared by two
# callers: Webhooks::PaymentProviderController (a real inbound HTTP
# request) and MockPaymentProvider::ProcessChargeJob (our simulated
# provider "calling back" in-process). Both go through the exact same
# verify -> dedupe -> enqueue path - the mock provider doesn't get a
# shortcut around signature verification just because it's internal.
module Webhooks
  class PaymentProviderProcessor
    Result = Struct.new(:status, :body, keyword_init: true)

    PROVIDER = "mock".freeze

    def self.call(raw_body:, signature_header:)
      new(raw_body: raw_body, signature_header: signature_header).call
    end

    def initialize(raw_body:, signature_header:)
      @raw_body = raw_body
      @signature_header = signature_header
    end

    # Deliberately does no DB writes at all on an invalid signature - we
    # don't trust the payload enough to even log its parsed contents until
    # we've verified who it's actually from.
    def call
      return unauthorized unless valid_signature?

      body = parse_body
      return bad_request("Malformed JSON body") unless body

      provider_event_id = body["id"]
      event_type = body["type"]
      return bad_request('Payload must include "id" and "type"') if provider_event_id.blank? || event_type.blank?

      webhook_event = WebhookEvent.create!(
        provider: PROVIDER,
        provider_event_id: provider_event_id,
        event_type: event_type,
        payload: body,
        signature_valid: true
      )

      ProcessWebhookEventJob.perform_later(webhook_event.id)

      ok
    rescue ActiveRecord::RecordNotUnique
      # Genuine race: two deliveries' uniqueness checks both passed before
      # either committed, and the DB unique index caught it. Same meaning
      # as the RecordInvalid case below: already received.
      ok
    rescue ActiveRecord::RecordInvalid => e
      # The common case: the model-level uniqueness validation already
      # caught a redelivered provider_event_id before it hit the DB.
      raise unless e.record.errors[:provider_event_id].present?

      ok
    end

    private

    attr_reader :raw_body, :signature_header

    def valid_signature?
      Webhooks::SignatureVerifier.valid?(payload: raw_body, signature_header: signature_header)
    end

    def parse_body
      parsed = JSON.parse(raw_body)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def ok
      Result.new(status: :ok)
    end

    def unauthorized
      Result.new(status: :unauthorized, body: { error: "Invalid signature" })
    end

    def bad_request(message)
      Result.new(status: :bad_request, body: { error: message })
    end
  end
end
