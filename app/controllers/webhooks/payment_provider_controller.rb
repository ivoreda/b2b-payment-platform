module Webhooks
  class PaymentProviderController < ActionController::API
    def create
      result = Webhooks::PaymentProviderProcessor.call(
        raw_body: request.raw_post,
        signature_header: request.headers["X-Webhook-Signature"]
      )

      result.body ? render(json: result.body, status: result.status) : head(result.status)
    end
  end
end
