module Orders
  # No parent row to lock here, so the (merchant_id, idempotency_key) unique index is the sole race guard.
  class Creator
    Result = Struct.new(:order, :idempotent_replay, keyword_init: true)

    def self.call(merchant:, idempotency_key:, order_params:)
      new(merchant: merchant, idempotency_key: idempotency_key, order_params: order_params).call
    end

    def initialize(merchant:, idempotency_key:, order_params:)
      @merchant = merchant
      @idempotency_key = idempotency_key
      @order_params = order_params
    end

    def call
      existing = merchant.orders.find_by(idempotency_key: idempotency_key)
      return build_replay_result(existing) if existing

      order = merchant.orders.create!(order_params.merge(idempotency_key: idempotency_key))
      Result.new(order: order, idempotent_replay: false)
    rescue ActiveRecord::RecordNotUnique
      # The DB unique index caught a race the pre-check missed.
      build_replay_result(merchant.orders.find_by!(idempotency_key: idempotency_key))
    rescue ActiveRecord::RecordInvalid => e
      # Same race, caught by the model validation instead of the DB index.
      raise unless e.record.errors[:idempotency_key].present?

      build_replay_result(merchant.orders.find_by!(idempotency_key: idempotency_key))
    end

    private

    attr_reader :merchant, :idempotency_key, :order_params

    def build_replay_result(existing)
      Result.new(order: existing, idempotent_replay: true)
    end
  end
end
