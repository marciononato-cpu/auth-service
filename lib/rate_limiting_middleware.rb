class RateLimitingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    ip = request.remote_ip
    path = request.path
    
    rate_limiter = case path
                   when "/api/users/sign_in"
                     RateLimiter.new("login", max_attempts: 5, period: 60)
                   when "/api/users"
                     RateLimiter.new("signup", max_attempts: 3, period: 60)
                   when "/api/passwords"
                     RateLimiter.new("password_reset", max_attempts: 2, period: 60)
                   else
                     nil
                   end

    if rate_limiter
      identifier = nil
      if path == "/api/passwords" && request.post?
        begin
          params = JSON.parse(request.body.read)
          identifier = params["password"]&.dig("email")&.downcase
        rescue
        end
      end

      if rate_limiter.blocked?(ip, identifier)
        return [429, { "Content-Type" => "application/json", "Retry-After" => "60" },
                [{ status: 429, error: "Muitas tentativas. Tente novamente em 1 minuto." }.to_json]]
      end

      if !rate_limiter.attempt(ip, identifier)
        return [429, { "Content-Type" => "application/json", "Retry-After" => "60" },
                [{ status: 429, error: "Muitas tentativas. Tente novamente em 1 minuto." }.to_json]]
      end
    end

    @app.call(env)
  end
end
