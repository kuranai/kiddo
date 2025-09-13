module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable connected for user: #{current_user.name}"
    end

    def disconnect
      Rails.logger.info "ActionCable disconnected for user: #{current_user&.name}"
    end

    private

    # Find the user from the session or authentication token
    def find_verified_user
      # Try to authenticate from session first (for web browser connections)
      if user_id = session_user_id
        user = User.find_by(id: user_id)
        return user if user
      end

      # Try to authenticate from cookies (for persistent connections)
      if user_id = cookie_user_id
        user = User.find_by(id: user_id)
        return user if user
      end

      # Try to authenticate from authorization header (for API connections)
      if token = auth_token
        user = authenticate_with_token(token)
        return user if user
      end

      # If no authentication method worked, reject the connection
      Rails.logger.warn "ActionCable connection rejected - no valid authentication"
      reject_unauthorized_connection
    end

    # Get user ID from session
    def session_user_id
      # Access the session through the request env
      session = request.session
      session[:user_id] if session
    rescue => e
      Rails.logger.warn "Failed to read session for ActionCable: #{e.message}"
      nil
    end

    # Get user ID from cookies (for remember me functionality)
    def cookie_user_id
      # Look for a signed user ID cookie
      cookies.signed[:user_id] if cookies.signed
    rescue => e
      Rails.logger.warn "Failed to read cookies for ActionCable: #{e.message}"
      nil
    end

    # Get authentication token from headers
    def auth_token
      # Check for authorization header
      if authorization_header = request.headers['Authorization']
        # Extract token from "Bearer <token>" format
        authorization_header.split(' ').last if authorization_header.start_with?('Bearer ')
      end
    end

    # Authenticate user with token (for API/mobile app connections)
    def authenticate_with_token(token)
      # For now, this is a placeholder - you could implement:
      # 1. JWT token validation
      # 2. API key lookup
      # 3. Session token validation
      # 4. OAuth token validation

      # Simple implementation: look for a user with this token as an API key
      # This would require adding an api_token field to users table
      # User.find_by(api_token: token)

      Rails.logger.info "Token authentication attempted but not implemented"
      nil
    end

    # Access cookies from the connection
    def cookies
      @cookies ||= ActionDispatch::Request.new(request.env).cookie_jar
    end

    # Access session from the connection
    def session
      @session ||= request.session
    end
  end
end