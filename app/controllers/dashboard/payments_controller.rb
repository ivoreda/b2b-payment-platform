module Dashboard
  class PaymentsController < ApplicationController
    before_action :require_login

    def create
      order = current_merchant.orders.find_by!(reference: params[:order_reference])

      Payments::Initiator.call(order: order, idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid)
      redirect_to dashboard_order_path(order), notice: "Payment initiated."
    rescue Payments::Initiator::OrderNotPayable
      redirect_to dashboard_order_path(order), alert: "This order can't accept a new payment right now."
    end
  end
end
