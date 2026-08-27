# Rate limiting for the two endpoints that don't already require a valid
# bearer token: login (credential-stuffing/brute-force target) and the
# webhook intake (a public, unauthenticated-by-session POST endpoint). Plus
# the bearer-token-authenticated API itself - a leaked token or a buggy
# client can still generate abusive traffic even though it's authenticated.
# Disabled in test by default so the rest of the suite isn't at the mercy
# of shared throttle state; specs that actually exercise this re-enable it
# explicitly and reset the cache around themselves.
class Rack::Attack
  throttle("logins/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/login"
  end

  throttle("webhooks/ip", limit: 60, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/webhooks/payment_provider"
  end

  # Signup creates a new Merchant + User + ApiCredential per request, unlike
  # login which just checks a password against an existing one - a much
  # tighter limit than logins/ip, since legitimate use is "once per person,"
  # not a repeated-attempt flow.
  throttle("signups/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/signup"
  end

  # A per-IP floor catches an unauthenticated flood (bad/no token) before it
  # ever reaches the controller. Generous relative to login/webhooks since a
  # legitimate integration can burst - this is an abuse backstop, not a
  # per-client fairness quota.
  throttle("api/ip", limit: 300, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  # A per-token cap on top of the IP one: a single leaked or misbehaving
  # credential shouldn't be able to hammer the API just by rotating IPs.
  # Keyed on a digest, not the raw token, so a live credential never sits in
  # the rate-limit cache in reusable form.
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
