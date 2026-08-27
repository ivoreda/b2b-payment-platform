# Safe to run twice for the same WebhookEvent - the guard below and Payment's own transitions are both idempotent.
class ProcessWebhookEventJob < ApplicationJob
  queue_as :default

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    return unless webhook_event.received?

    payment = Payment.find_by(reference: webhook_event.payload.dig("data", "payment_reference"))

    unless payment
      webhook_event.update!(status: :ignored, error_message: "No payment found for the given payment_reference")
      return
    end

    webhook_event.update!(payment: payment)

    case webhook_event.event_type
    when "payment.succeeded"
      payment.mark_succeeded!(
        provider_reference: webhook_event.payload.dig("data", "provider_reference"),
        webhook_event: webhook_event
      )
    when "payment.failed"
      payment.mark_failed!(
        failure_reason: webhook_event.payload.dig("data", "failure_reason"),
        webhook_event: webhook_event
      )
    else
      webhook_event.update!(status: :ignored, error_message: "Unrecognized event_type: #{webhook_event.event_type}")
      return
    end

    webhook_event.update!(status: :processed)
  rescue Payment::InvalidTransition => e
    # Not retryable, so record it instead of raising into Solid Queue's retry loop.
    webhook_event.update!(status: :failed, error_message: e.message)
  end
end
