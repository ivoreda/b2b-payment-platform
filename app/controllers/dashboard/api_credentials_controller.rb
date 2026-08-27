module Dashboard
  # The one place User#role is actually enforced - minting/revoking tokens is admin-only.
  class ApiCredentialsController < ApplicationController
    before_action :require_login
    before_action :require_admin

    def index
      @api_credentials = current_merchant.api_credentials.order(created_at: :desc)
    end

    def create
      credential = current_merchant.api_credentials.new(credential_params)

      if credential.save
        # Flash is the only way to carry the raw token across the redirect for a one-time reveal.
        redirect_to dashboard_api_credentials_path, notice: "API credential '#{credential.name}' created."
        flash[:api_token] = credential.token
      else
        @api_credentials = current_merchant.api_credentials.order(created_at: :desc)
        @new_credential = credential
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      credential = current_merchant.api_credentials.find(params[:id])
      credential.revoke!

      redirect_to dashboard_api_credentials_path, notice: "API credential '#{credential.name}' revoked."
    end

    private

    def credential_params
      params.require(:api_credential).permit(:name)
    end

    def require_admin
      return if current_user.admin?

      redirect_to dashboard_orders_path, alert: "You don't have permission to do that."
    end
  end
end
