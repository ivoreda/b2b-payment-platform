# Disabled in test by default; specs that exercise this re-enable it and reset the cache around themselves.
class Rack::Attack
  throttle("logins/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/login"
  end

  throttle("webhooks/ip", limit: 60, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/webhooks/payment_provider"
  end

  # Tighter than logins/ip - legitimate signup is once per person, not a repeated-attempt flow.
  throttle("signups/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/signup"
  end

  # An abuse backstop for unauthenticated floods, generous enough for a legitimate integration's bursts.
  throttle("api/ip", limit: 300, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  # Per-token cap on top of the IP one, keyed on a digest so a live token never sits in the cache in reusable form.
  throttle("api/token", limit: 300, period: 1.minute) do |request|
    next unless request.path.start_with?("/api/")

    auth_header = request.get_header("HTTP_AUTHORIZATION").to_s
    token = auth_header.delete_prefix("Bearer ").strip if auth_header.start_with?("Bearer ")
    Digest::SHA256.hexdigest(token) if token.present?
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "application/json" }, [ { error: "Rate limit exceeded" }.to_json ] ]
  end
end

Rack::Attack.enabled = !Rails.env.test?
