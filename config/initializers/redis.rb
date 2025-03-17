require 'redis'

# Configure Redis connection
redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/1"

begin
  $redis = Redis.new(url: redis_url)
  
  # Test connection
  $redis.ping
  
  Rails.logger.info "Connected to Redis at #{redis_url.gsub(/:[^:]*@/, ':****@')}"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Failed to connect to Redis at #{redis_url.gsub(/:[^:]*@/, ':****@')}: #{e.message}"
  
  # Fallback to a dummy Redis implementation that doesn't throw errors
  # This allows the application to start even without Redis
  Rails.logger.warn "Using dummy Redis implementation as fallback"
  
  class DummyRedis
    def method_missing(method, *args, &block)
      Rails.logger.debug "DummyRedis: Called #{method} with #{args.inspect}"
      nil
    end
    
    def ping
      "PONG"
    end
    
    def set(key, value, options = {})
      Rails.logger.debug "DummyRedis: Setting #{key} to #{value} with options #{options.inspect}"
      "OK"
    end
    
    def get(key)
      Rails.logger.debug "DummyRedis: Getting #{key}"
      nil
    end
  end
  
  $redis = DummyRedis.new
end