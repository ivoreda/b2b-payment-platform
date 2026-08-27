module Dashboard
  class OrdersController < ApplicationController
    before_action :require_login

    def index
      @orders = current_merchant.orders.includes(:payments).order(created_at: :desc)
    end

    def show
      @order = current_merchant.orders.find_by!(reference: params[:reference])
      @payments = @order.payments.order(created_at: :desc)
      @payment_events = PaymentEvent.where(payment: @payments).includes(:payment).order(created_at: :desc)
      # A double-click resubmit reuses this key; Payments::Initiator collapses it into one payment.
      @payment_idempotency_key = SecureRandom.uuid
    end

    def new
      @order = current_merchant.orders.new(currency: "USD")
      # Same double-click guard as payment initiation.
      @order_idempotency_key = SecureRandom.uuid
    end

    def create
      result = Orders::Creator.call(
        merchant: current_merchant,
        idempotency_key: params[:order][:idempotency_key].presence || SecureRandom.uuid,
        order_params: order_params.merge(amount_cents: amount_cents_from_dollars(params[:order][:amount]))
      )
      redirect_to dashboard_order_path(result.order), notice: "Order created."
    rescue ActiveRecord::RecordInvalid => e
      @order = e.record
      @order_idempotency_key = params[:order][:idempotency_key]
      render :new, status: :unprocessable_content
    end

    private

    # :status excluded - orders always start pending, never client-settable.
    def order_params
      params.require(:order).permit(:currency, :customer_email, :customer_name)
    end

    # BigDecimal avoids the float-precision drift a plain `.to_f * 100` risks.
    def amount_cents_from_dollars(dollars)
      return nil if dollars.blank?

      (BigDecimal(dollars) * 100).round.to_i
    rescue ArgumentError
      nil
    end
  end
end
