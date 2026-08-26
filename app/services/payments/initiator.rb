module Payments
  # Creates a Payment against an Order and transitions the Order out of
  # `pending`, all under a row lock so concurrent initiation attempts on the
  # same order can't both slip past the "is this order payable" check.
  #
  # Idempotency-Key handling is intentionally two-layered: the in-transaction
  # lookup handles the common case cheaply, while rescuing the unique-index
  # violation on (merchant_id, idempotency_key) covers the race where two
  # concurrent requests for *different* orders under the same merchant reuse
  # the same key - a plain row lock on one order can't serialize against that.
  class Initiator
    Result = Struct.new(:payment, :idempotent_replay, keyword_init: true)

    class OrderNotPayable < StandardError; end
    class IdempotencyKeyConflict < StandardError; end

    def self.call(order:, idempotency_key:)
      new(order: order, idempotency_key: idempotency_key).call
    end

    def initialize(order:, idempotency_key:)
      @order = order
      @idempotency_key = idempotency_key
    end

    def call
      result = order.with_lock do
        if idempotency_key.present?
          existing = order.merchant.payments.find_by(idempotency_key: idempotency_key)
          break build_replay_result(existing) if existing
        end

        raise OrderNotPayable, order.status unless order.pending? || order.awaiting_payment?

        payment = order.payments.create!(
          merchant: order.merchant,
          amount_cents: order.amount_cents,
          currency: order.currency,
          idempotency_key: idempotency_key
        )

        order.update!(status: :awaiting_payment) if order.pending?

        Result.new(payment: payment, idempotent_replay: false)
      end

      # Only kick off the (simulated) charge for a genuinely new payment, and
      # only once the transaction above has actually committed - enqueuing
      # from inside an open transaction risks the job running before the
      # row it needs is visible.
      MockPaymentProvider.charge(result.payment) unless result.idempotent_replay

      result
    rescue ActiveRecord::RecordNotUnique
      build_replay_result(order.merchant.payments.find_by!(idempotency_key: idempotency_key))
    end

    private

    attr_reader :order, :idempotency_key

    def build_replay_result(existing)
      raise IdempotencyKeyConflict, idempotency_key if existing.order_id != order.id

      Result.new(payment: existing, idempotent_replay: true)
    end
  end
end
