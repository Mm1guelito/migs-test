class ApplicationController < ActionController::Base
  # Make current_user available in all views
  helper_method :current_user

  private

  # Returns the currently logged in user or nil if not logged in
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # Redirects to login page if user is not authenticated
  def authenticate_user!
    unless current_user
      redirect_to root_path, alert: "Please sign in to continue"
    end
  end
end
