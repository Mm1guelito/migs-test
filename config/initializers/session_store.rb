# Configure the session store to use cookies with a long expiration time
Rails.application.config.session_store :cookie_store,
  key: '_jump_session',
  expire_after: 1.year,  # Session will last for 1 year
  secure: Rails.env.production?,  # Only use secure cookies in production
  httponly: true  # Prevent JavaScript access to the session cookie 