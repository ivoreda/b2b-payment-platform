module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_merchant!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      attr_reader :current_api_credential

      def authenticate_merchant!
        @current_api_credential = ApiCredential.authenticate(bearer_token)

        render_unauthorized unless current_api_credential
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")

        header.delete_prefix("Bearer ").strip.presence
      end

      def current_merchant
        current_api_credential&.merchant
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
