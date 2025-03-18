require 'redis'

# Configure Redis connection
redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/1"

# Debug logs
Rails.logger.debug "Redis URL from ENV: #{ENV['REDIS_URL'].inspect}"
Rails.logger.debug "Using Redis URL: #{redis_url.gsub(/:[^:]*@/, ':****@')}"

begin
  # More detailed connection options
  uri = URI.parse(redis_url)
  redis_connection_info = {
    host: uri.host,
    port: uri.port,
    db: uri.path.gsub('/', '').presence || 0,
    password: uri.password
  }
  Rails.logger.debug "Redis connection details: host=#{uri.host}, port=#{uri.port}, db=#{uri.path.gsub('/', '').presence || 0}"
  
  $redis = Redis.new(url: redis_url)
  
  # Test connection
  ping_result = $redis.ping
  
  Rails.logger.info "Connected to Redis at #{redis_url.gsub(/:[^:]*@/, ':****@')}, PING response: #{ping_result}"
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