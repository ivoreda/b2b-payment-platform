# Shared HMAC secret between our mock payment provider and our own webhook
# endpoint. In production this must come from the environment - failing
# fast at boot beats silently accepting unsigned/forgeable webhooks.
Rails.application.config.mock_payment_provider_webhook_secret =
  ENV.fetch("MOCK_PROVIDER_WEBHOOK_SECRET") do
    raise "MOCK_PROVIDER_WEBHOOK_SECRET must be set in production" if Rails.env.production?

    "insecure_development_only_mock_provider_webhook_secret"
  end
