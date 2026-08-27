# Required in production - fails fast at boot rather than accepting unsigned webhooks.
# Skipped when SECRET_KEY_BASE_DUMMY is set (Docker asset-precompile boot; see Dockerfile).
Rails.application.config.mock_payment_provider_webhook_secret =
  ENV.fetch("MOCK_PROVIDER_WEBHOOK_SECRET") do
    if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
      raise "MOCK_PROVIDER_WEBHOOK_SECRET must be set in production"
    end

    "insecure_development_only_mock_provider_webhook_secret"
  end
