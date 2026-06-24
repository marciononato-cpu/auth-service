# lib/cors_middleware.rb
# Middleware que bloqueia OPTIONS de origens não permitidas e adiciona headers CORS
# Este middleware vai antes de tudo para garantir bloqueio real

class CorsMiddleware
  def initialize(app)
    @app = app
    # Regex: localhost (com/sem porta), 127.0.0.1 (com/sem porta), labono.duckdns.org
    @allowed_pattern = /\Ahttps?:\/\/(localhost(:\d+)?|127\.0\.0\.1(:\d+)?|labono\.duckdns\.org)\z/
  end

  def call(env)
    method = env['REQUEST_METHOD']
    origin = env['HTTP_ORIGIN']
    
    if method == 'OPTIONS' && origin
      if @allowed_pattern.match?(origin)
        # Origem permitida — adicionar headers CORS e permitir
        status, headers, body = @app.call(env)
        headers['Access-Control-Allow-Origin'] = origin
        headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD'
        headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-Requested-With'
        headers['Access-Control-Max-Age'] = '86400'
        [status, headers, body]
      else
        # Origem NÃO permitida — bloquear
        [
          403,
          {
            'Content-Type' => 'application/json',
            'Content-Length' => '2',
            'X-Cors-Blocked' => 'true'
          },
          ['{}']
        ]
      end
    elsif origin
      # Não é OPTIONS mas tem Origin — adicionar headers CORS
      if @allowed_pattern.match?(origin)
        status, headers, body = @app.call(env)
        headers['Access-Control-Allow-Origin'] = origin
        headers['Access-Control-Expose-Headers'] = 'Authorization, X-Total-Count, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset'
        [status, headers, body]
      else
        # Não é OPTIONS nem origin permitida — deixar o Rails lidar
        @app.call(env)
      end
    else
      # Sem Origin — comportamento normal
      @app.call(env)
    end
  end
end
