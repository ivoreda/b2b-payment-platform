module Webhooks
  class PaymentProviderController < ActionController::API
    PROVIDER = "mock".freeze

    # Deliberately does no DB writes at all on an invalid signature - we
    # don't trust the payload enough to even log its parsed contents until
    # we've verified who it's actually from.
    def create
      return render_unauthorized unless valid_signature?

      body = parse_body
      return render_bad_request("Malformed JSON body") unless body

      provider_event_id = body["id"]
      event_type = body["type"]
      return render_bad_request("Payload must include \"id\" and \"type\"") if provider_event_id.blank? || event_type.blank?

      webhook_event = WebhookEvent.create!(
        provider: PROVIDER,
        provider_event_id: provider_event_id,
        event_type: event_type,
        payload: body,
        signature_valid: true
      )

      ProcessWebhookEventJob.perform_later(webhook_event.id)

      head :ok
    rescue ActiveRecord::RecordNotUnique
      # Genuine race: two deliveries' uniqueness checks both passed before
      # either committed, and the DB unique index caught it. Same meaning
      # as the RecordInvalid case below: already received.
      head :ok
    rescue ActiveRecord::RecordInvalid => e
      # The common case: the model-level uniqueness validation already
      # caught a redelivered provider_event_id before it hit the DB.
      raise unless e.record.errors[:provider_event_id].present?

      head :ok
    end

    private

    def valid_signature?
      Webhooks::SignatureVerifier.valid?(
        payload: request.raw_post,
        signature_header: request.headers["X-Webhook-Signature"]
      )
    end

    def parse_body
      parsed = JSON.parse(request.raw_post)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def render_unauthorized
      render json: { error: "Invalid signature" }, status: :unauthorized
    end

    def render_bad_request(message)
      render json: { error: message }, status: :bad_request
    end
  end
end
