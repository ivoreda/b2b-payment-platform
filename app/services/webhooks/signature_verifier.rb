# Stripe-style webhook signing: header is "t=<unix_ts>,v1=<hmac>", where the
# hmac covers "<timestamp>.<raw body>". Binding the timestamp into the signed
# material (not just checking it separately) means a captured, genuinely
# valid signature can't be replayed indefinitely - it's only valid within
# TOLERANCE of when it was generated. This class both verifies (the
# controller) and generates (the mock provider, and specs) since both sides
# need to agree on the exact same scheme and secret.
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
