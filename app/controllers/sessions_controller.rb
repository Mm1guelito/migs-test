# Handles user authentication sessions
# This controller manages the OAuth callback from Google and creates/updates user records
class SessionsController < ApplicationController
  # Handles the callback from Google OAuth
  # Creates or finds a user based on their Google ID
  # Stores the user's ID and access token in the session
  def google_auth
    auth = request.env['omniauth.auth']
    
    if session[:user_id].present?
      # Adding a new Google account to existing user
      add_google_account(auth)
    else
      # Initial user authentication
      create_or_find_user(auth)
    end
    
    # Check if there's a pending meeting URL to redirect to
    if session[:pending_meeting_url].present?
      meeting_url = session[:pending_meeting_url]
      
      # If this is a Google Meet, add the authuser parameter with the selected account's email
      if meeting_url.include?('meet.google.com')
        meeting_url = meeting_url + (meeting_url.include?('?') ? '&' : '?') + "authuser=#{auth['info']['email']}"
      end
      
      session.delete(:pending_meeting_url)
      redirect_to meeting_url, allow_other_host: true
    else
      redirect_to welcome_path
    end
  end

  # Handles the callback from LinkedIn OAuth
  def linkedin_auth
    auth = request.env['omniauth.auth']
    
    if session[:user_id].present?
      # Adding a new LinkedIn account to existing user
      add_linkedin_account(auth)
    else
      # Initial user authentication
      create_or_find_user_from_linkedin(auth)
    end
    
    redirect_to settings_path
  end

  # Handles user sign out
  # Clears the session and redirects to home page
  def sign_out
    # Clear all session data
    session.delete(:user_id)
    session.delete(:access_token)
    session.delete(:refresh_token)
    session.delete(:token_expires_at)
    reset_session
    
    # Redirect to root path with a success message
    redirect_to root_path, notice: 'You have been signed out successfully.'
  end
  
  # Removes a secondary Google account
  def remove_account
    account = current_user.google_accounts.find(params[:id])
    
    if account.is_primary?
      redirect_to settings_path, alert: "Cannot remove primary account"
    else
      account.destroy
      redirect_to settings_path, notice: "Account removed successfully"
    end
  end

  # Removes a secondary LinkedIn account
  def remove_linkedin_account
    account = current_user.linkedin_accounts.find(params[:id])
    
    if account.is_primary?
      redirect_to settings_path, alert: "Cannot remove primary account"
    else
      account.destroy
      redirect_to settings_path, notice: "LinkedIn account removed successfully"
    end
  end
  
  # Toggles calendar sync for a Google account
  def toggle_calendar_sync
    account = current_user.google_accounts.find(params[:id])
    account.update(calendar_sync_enabled: !account.calendar_sync_enabled)
    
    redirect_to settings_path, notice: "Calendar sync #{account.calendar_sync_enabled? ? 'enabled' : 'disabled'}"
  end
  
  private
  
  def create_or_find_user(auth)
    user = User.find_or_create_by(google_id: auth['uid']) do |u|
      u.email = auth['info']['email']
      u.first_name = auth['info']['first_name']
      u.last_name = auth['info']['last_name']
    end
    
    # Store user ID and tokens in session
    session[:user_id] = user.id
    session[:access_token] = auth['credentials']['token']
    session[:refresh_token] = auth['credentials']['refresh_token']
    session[:token_expires_at] = Time.at(auth['credentials']['expires_at'])
  end

  def create_or_find_user_from_linkedin(auth)
    user = User.find_or_create_by(linkedin_id: auth['uid']) do |u|
      u.email = auth['info']['email']
      u.first_name = auth['info']['first_name']
      u.last_name = auth['info']['last_name']
    end
    
    # Store user ID and tokens in session
    session[:user_id] = user.id
    session[:access_token] = auth['credentials']['token']
    session[:refresh_token] = auth['credentials']['refresh_token']
    session[:token_expires_at] = Time.at(auth['credentials']['expires_at'])
  end
  
  def add_google_account(auth)
    user = User.find(session[:user_id])
    
    # Create or update the Google account with calendar sync enabled by default
    account = user.google_accounts.find_or_initialize_by(google_id: auth['uid'])
    account.update!(
      email: auth['info']['email'],
      first_name: auth['info']['first_name'],
      last_name: auth['info']['last_name'],
      access_token: auth['credentials']['token'],
      refresh_token: auth['credentials']['refresh_token'],
      token_expires_at: Time.at(auth['credentials']['expires_at']),
      calendar_sync_enabled: true
    )
    
    flash[:notice] = "Successfully added #{account.email} to your accounts"
  end

  def add_linkedin_account(auth)
    user = User.find(session[:user_id])
    
    # Create or update the LinkedIn account
    account = user.linkedin_accounts.find_or_initialize_by(linkedin_id: auth['uid'])
    account.update!(
      email: auth['info']['email'],
      first_name: auth['info']['first_name'],
      last_name: auth['info']['last_name'],
      access_token: auth['credentials']['token'],
      refresh_token: auth['credentials']['refresh_token'],
      token_expires_at: Time.at(auth['credentials']['expires_at']),
      profile_url: auth['info']['urls']['public_profile'],
      headline: auth['extra']['raw_info']['headline']
    )
    
    flash[:notice] = "Successfully added LinkedIn account #{account.email} to your accounts"
  end
end 