class RateLimitingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Pega o IP real, considerando o proxy reverso
    ip = request.remote_ip
    
    # Extrai o caminho da rota
    path = request.path
    
    rate_limiter = case path
                   when '/api/users/sign_in'
                     # Login: 5 tentativas por IP a cada 60 segundos
                     RateLimiter.new('login', max_attempts: 5, period: 60)
                   when '/api/users'
                     # Cadastro: 3 tentativas por IP a cada 60 segundos
                     RateLimiter.new('signup', max_attempts: 3, period: 60)
                   when '/api/passwords'
                     # Reset: 2 tentativas por IP a cada 60 segundos
                     RateLimiter.new('password_reset', max_attempts: 2, period: 60)
                   else
                     nil
                   end

    if rate_limiter
      identifier = nil
      # Se for reset de senha, usamos o email como identificador adicional
      if path == '/api/passwords' && request.post?
        begin
          params = JSON.parse(request.body.read)
          identifier = params['password']&.dig('email')&.downcase
        rescue
          # Se não conseguir parsear, continua sem identificador
        end
      end

      if rate_limiter.blocked?(ip, identifier)
        # Retorna 429 Too Many Requests
        return [429, { 'Content-Type' => 'application/json', 'Retry-After' => '60' },
                [{ status: 429, error: 'Muitas tentativas. Tente novamente em 1 minuto.' }.to_json]]
      end

      if !rate_limiter.attempt(ip, identifier)
        return [429, { 'Content-Type' => 'application/json', 'Retry-After' => '60' },
                [{ status: 429, error: 'Muitas tentativas. Tente novamente em 1 minuto.' }.to_json]]
      end
    end

    @app.call(env)
  end
end
