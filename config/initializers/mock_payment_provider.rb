# Shared HMAC secret between our mock payment provider and our own webhook
# endpoint. In production this must come from the environment - failing
# fast at boot beats silently accepting unsigned/forgeable webhooks.
#
# SECRET_KEY_BASE_DUMMY is Rails' own signal for "this boot is asset
# precompilation at Docker build time, not a real server start" (see the
# Dockerfile) - real secrets, including this one, aren't available yet at
# that point, so the fail-fast is skipped for that boot only.
Rails.application.config.mock_payment_provider_webhook_secret =
  ENV.fetch("MOCK_PROVIDER_WEBHOOK_SECRET") do
    if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
      raise "MOCK_PROVIDER_WEBHOOK_SECRET must be set in production"
    end

    "insecure_development_only_mock_provider_webhook_secret"
  end
