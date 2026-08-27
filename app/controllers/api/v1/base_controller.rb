module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_merchant!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable

      private

      attr_reader :current_api_credential

      def authenticate_merchant!
        @current_api_credential = ApiCredential.authenticate(bearer_token)

        return render_unauthorized unless current_api_credential

        # Deliberately distinct from a bad/missing token: the credential is
        # genuinely valid, but the merchant account behind it has been
        # suspended (fraud, non-payment, offboarding, compliance hold) - the
        # caller needs to know to stop retrying with the same token, not
        # assume it's expired and fetch a new one.
        render_forbidden("Merchant account is suspended") if current_api_credential.merchant.suspended?
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")

        header.delete_prefix("Bearer ").strip.presence
      end

      def current_merchant
        current_api_credential&.merchant
      end

      def idempotency_key_header
        request.headers["Idempotency-Key"].presence
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_forbidden(message)
        render json: { error: message }, status: :forbidden
      end

      def render_missing_idempotency_key
        render json: { error: "Idempotency-Key header is required" }, status: :bad_request
      end

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def render_unprocessable(exception)
        render json: { error: "Validation failed", details: exception.record.errors.full_messages },
               status: :unprocessable_content
      end
    end
  end
end
