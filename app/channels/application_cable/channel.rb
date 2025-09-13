module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # Common functionality for all channels can be added here

    private

    # Ensure user is authenticated before allowing channel operations
    def ensure_authenticated!
      reject unless current_user
    end

    # Ensure user has parent role for parent-only channels
    def ensure_parent!
      reject unless current_user&.parent?
    end

    # Ensure user has kid role for kid-only channels
    def ensure_kid!
      reject unless current_user&.kid?
    end

    # Log channel activity for debugging/monitoring
    def log_channel_activity(action, data = {})
      Rails.logger.info "Channel Activity - #{self.class.name}: #{action} by #{current_user&.name} - #{data}"
    end

    # Handle common error cases
    def handle_channel_error(error, context = "channel operation")
      Rails.logger.error "#{self.class.name} error during #{context}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

      transmit({
        type: :error,
        message: "An error occurred during #{context}",
        timestamp: Time.current.iso8601
      })
    end

    # Validate required parameters
    def validate_params(data, required_keys)
      missing_keys = required_keys - data.keys.map(&:to_s)
      unless missing_keys.empty?
        transmit({
          type: :error,
          message: "Missing required parameters: #{missing_keys.join(', ')}",
          timestamp: Time.current.iso8601
        })
        return false
      end
      true
    end

    # Rate limiting for channel operations (simple implementation)
    def rate_limit_check(operation, limit_per_minute = 30)
      cache_key = "rate_limit:#{current_user.id}:#{operation}"
      current_count = Rails.cache.read(cache_key) || 0

      if current_count >= limit_per_minute
        transmit({
          type: :error,
          message: "Rate limit exceeded. Please wait before trying again.",
          timestamp: Time.current.iso8601
        })
        return false
      end

      Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
      true
    end
  end
end