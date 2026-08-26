# Rate limiting for the two endpoints that don't already require a valid
# bearer token: login (credential-stuffing/brute-force target) and the
# webhook intake (a public, unauthenticated-by-session POST endpoint).
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

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "application/json" }, [ { error: "Rate limit exceeded" }.to_json ] ]
  end
end

Rack::Attack.enabled = !Rails.env.test?
