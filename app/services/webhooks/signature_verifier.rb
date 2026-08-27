# Stripe-style webhook signing: "t=<unix_ts>,v1=<hmac>" over "<timestamp>.<raw body>",
# so a captured signature is only replayable within TOLERANCE of when it was generated.
module Webhooks
  class SignatureVerifier
    TOLERANCE = 5.minutes

    class << self
      def valid?(payload:, signature_header:)
        new(payload).valid_signature?(signature_header)
      end

      def header_for(payload, timestamp: Time.now.to_i)
        new(payload).header(timestamp)
      end
    end

    def initialize(payload)
      @payload = payload.to_s
    end

    def valid_signature?(signature_header)
      timestamp, signature = parse(signature_header)
      return false unless timestamp && signature
      return false unless recent?(timestamp)

      ActiveSupport::SecurityUtils.secure_compare(signature, signature_for(timestamp))
    end

    def header(timestamp)
      "t=#{timestamp},v1=#{signature_for(timestamp)}"
    end

    private

    attr_reader :payload

    def parse(signature_header)
      pairs = signature_header.to_s.split(",").filter_map do |part|
        key, value = part.split("=", 2)
        [ key, value ] if key && value
      end.to_h

      [ pairs["t"], pairs["v1"] ]
    end

    def recent?(raw_timestamp)
      timestamp = Integer(raw_timestamp, exception: false)
      return false unless timestamp

      (Time.now.to_i - timestamp).abs <= TOLERANCE
    end

    def signature_for(timestamp)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    end

    def secret
      Rails.application.config.mock_payment_provider_webhook_secret
    end
  end
end
