# OmniAuth configuration for Google OAuth2, LinkedIn, and Zoom
# Sets up OAuth providers with client credentials from environment variables

Rails.application.config.middleware.use OmniAuth::Builder do
  # Google OAuth2 configuration
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
    scope: 'email,profile,https://www.googleapis.com/auth/calendar.readonly',
    prompt: 'select_account',
    access_type: 'online',
    skip_jwt: true,
    provider_ignores_state: false
  }
  
  # LinkedIn OpenID Connect configuration with direct credentials
  provider :openid_connect, {
    name: :linkedin,
    scope: [:openid, :profile, :email],
    response_type: :code,
    issuer: 'https://www.linkedin.com/oauth',
    discovery: false,
    client_options: {
      identifier: ENV['LINKEDIN_CLIENT_ID'],
      secret: ENV['LINKEDIN_CLIENT_SECRET'],
      redirect_uri: 'http://127.0.0.1:3000/auth/linkedin/callback',
      host: 'www.linkedin.com',
      scheme: 'https',
      authorization_endpoint: 'https://www.linkedin.com/oauth/v2/authorization',
      token_endpoint: 'https://www.linkedin.com/oauth/v2/accessToken',
      userinfo_endpoint: 'https://api.linkedin.com/v2/me',
      # Token exchange configuration
      token_method: :post,
      auth_scheme: :request_body,
      client_auth_method: :basic,
      # Ensure client credentials are properly sent
      send_client_credentials_in_body: true
    },
    # Additional OpenID Connect options
    uid_field: 'id',
    client_signing_alg: :RS256,
    client_jwk_signing_key: nil,
    client_x509_signing_key: nil,
    send_nonce: false,
    send_scope_to_token_endpoint: true,
    post_logout_redirect_uri: nil
  }
  
  # Zoom OAuth2 configuration
  provider :zoom, ENV['ZOOM_CLIENT_ID'], ENV['ZOOM_CLIENT_SECRET'], {
    scope: 'user:read meeting:read',
    provider_ignores_state: false
  }
end

# Configure OmniAuth to use Rails CSRF protection
OmniAuth.config.allowed_request_methods = [:post, :get]