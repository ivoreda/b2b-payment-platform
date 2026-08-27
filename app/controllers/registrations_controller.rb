# Self-service merchant signup. Creates a brand-new Merchant together with
# its first User (always `admin` - there's no one else yet to have granted
# that role) and one API credential, so a merchant leaves this flow with
# every kind of access already usable, not just a dashboard login.
class RegistrationsController < ApplicationController
  before_action :redirect_if_logged_in, only: %i[new create]

  def new
    @merchant = Merchant.new
    @user = User.new
  end

  def create
    @merchant = Merchant.new(merchant_params)
    @user = @merchant.users.new(user_params.merge(role: :admin))

    if @merchant.valid? && @user.valid?
      credential = nil

      ActiveRecord::Base.transaction do
        @merchant.save!
        @user.save!
        credential = @merchant.api_credentials.create!(name: "Default Key")
      end

      reset_session
      session[:user_id] = @user.id
      flash[:api_token] = credential.token
      redirect_to dashboard_api_credentials_path, notice: "Welcome! Your account has been created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def merchant_params
    params.require(:merchant).permit(:name)
  end

  # Deliberately excludes :role - always server-set to :admin above, never
  # client-controlled, for the same reason Order#status is never permitted
  # from client params.
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
