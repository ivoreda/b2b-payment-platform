module Payments
  # Creates a Payment and moves the Order out of `pending` under a row lock. Idempotency-Key is checked
  # both in-transaction and via the (merchant_id, idempotency_key) unique index, since a lock on one order
  # can't serialize against a race across two different orders.
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

      # Only for a genuinely new payment, and only after the transaction above has committed.
      MockPaymentProvider.charge(result.payment) unless result.idempotent_replay

      result
    rescue ActiveRecord::RecordNotUnique
      # The DB unique index caught a race the pre-check missed.
      build_replay_result(order.merchant.payments.find_by!(idempotency_key: idempotency_key))
    rescue ActiveRecord::RecordInvalid => e
      # Same race, caught by the model validation instead of the DB index.
      raise unless e.record.errors[:idempotency_key].present?

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
