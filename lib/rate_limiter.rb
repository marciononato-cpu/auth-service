class RateLimiter
  def initialize(key_prefix, max_attempts: 5, period: 60)
    @key_prefix = key_prefix
    @max_attempts = max_attempts
    @period = period
  end

  def attempt(ip, identifier = nil)
    key = if identifier
            "\#{@key_prefix}:\#{identifier}:\#{ip}"
          else
            "\#{@key_prefix}:\#{ip}"
          end
    
    count = Rails.cache.fetch("limit:\#{key}") { 0 }
    count += 1
    
    if count <= @max_attempts
      Rails.cache.write("limit:\#{key}", count, expires_in: @period)
      true
    else
      if count == @max_attempts + 1
        Rails.cache.write("block:\#{key}", true, expires_in: @period)
      end
      false
    end
  end

  def blocked?(ip, identifier = nil)
    key = if identifier
            "\#{@key_prefix}:\#{identifier}:\#{ip}"
          else
            "\#{@key_prefix}:\#{ip}"
          end
    
    Rails.cache.read("block:\#{key}") == true
  end

  def reset(ip, identifier = nil)
    key = if identifier
            "\#{@key_prefix}:\#{identifier}:\#{ip}"
          else
            "\#{@key_prefix}:\#{ip}"
          end
    
    Rails.cache.delete("limit:\#{key}")
    Rails.cache.delete("block:\#{key}")
  end
end
