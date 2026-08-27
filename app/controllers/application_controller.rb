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

  # Also covers a merchant suspended mid-session, not just a suspended
  # merchant's user logging in fresh: this runs on every dashboard request,
  # not only at login, so suspension takes effect immediately rather than
  # waiting for the current session to expire on its own.
  def require_login
    unless current_user
      redirect_to login_path, alert: "Please log in to continue."
      return
    end

    if current_merchant.suspended?
      reset_session
      redirect_to login_path, alert: "This merchant account has been suspended."
    end
  end

  def redirect_if_logged_in
    redirect_to root_path if current_user
  end
end
