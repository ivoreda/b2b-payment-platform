module Api
  module V1
    class OrdersController < BaseController
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      def index
        @page = [ params[:page].to_i, 1 ].max
        @per_page = per_page_param
        @orders = current_merchant.orders
                                   .order(created_at: :desc)
                                   .limit(@per_page)
                                   .offset((@page - 1) * @per_page)
      end

      def show
        @order = current_merchant.orders.find_by!(reference: params[:reference])
      end

      def create
        @order = current_merchant.orders.new(order_params)

        if @order.save
          render :show, status: :created
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      # Deliberately excludes :status - order status is only ever changed by
      # our own domain logic (payment initiation/webhooks), never directly by
      # a client request.
      def order_params
        params.require(:order).permit(:amount_cents, :currency, :customer_email, :customer_name)
      end

      def per_page_param
        requested = params[:per_page].to_i
        return DEFAULT_PER_PAGE if requested <= 0

        [ requested, MAX_PER_PAGE ].min
      end
    end
  end
end
