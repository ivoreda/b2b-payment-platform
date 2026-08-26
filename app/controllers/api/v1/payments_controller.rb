module Api
  module V1
    class PaymentsController < BaseController
      before_action :set_order, only: :create

      def create
        idempotency_key = request.headers["Idempotency-Key"].presence
        return render_missing_idempotency_key unless idempotency_key

        result = Payments::Initiator.call(order: @order, idempotency_key: idempotency_key)
        @payment = result.payment

        render :show, status: result.idempotent_replay ? :ok : :created
      rescue Payments::Initiator::OrderNotPayable
        render json: { error: "Order is not payable in its current status (#{@order.reload.status})" },
               status: :unprocessable_content
      rescue Payments::Initiator::IdempotencyKeyConflict
        render json: { error: "Idempotency-Key has already been used for a different order" }, status: :conflict
      end

      def show
        @payment = current_merchant.payments.find_by!(reference: params[:reference])
        render :show
      end

      private

      def set_order
        @order = current_merchant.orders.find_by!(reference: params[:order_reference])
      end

      def render_missing_idempotency_key
        render json: { error: "Idempotency-Key header is required" }, status: :bad_request
      end
    end
  end
end
