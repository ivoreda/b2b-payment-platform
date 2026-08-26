class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_merchant

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def current_merchant
    current_user&.merchant
  end

  def require_login
    return if current_user

    redirect_to login_path, alert: "Please log in to continue."
  end
end
