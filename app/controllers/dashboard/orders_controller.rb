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
      # Regenerated on every render of this page (not tied to the order or
      # session), so a genuine reload/revisit gets a fresh key while a
      # double-click on the same rendered form submits the same key twice -
      # which Payments::Initiator already collapses into a single payment.
      @payment_idempotency_key = SecureRandom.uuid
    end
  end
end
