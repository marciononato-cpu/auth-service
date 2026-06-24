class RateLimitingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Consumir o body para poder reler depois
    request.body.rewind if request.body.respond_to?(:rewind)
    
    ip = request.remote_ip
    method = request.method
    path = request.path
    
    # Configurar limites por endpoint
    limits = get_rate_limits(path, method)
    return @app.call(env) unless limits
    
    max_attempts, period = limits
    
    # Checar se está bloqueado (limite excedido anteriormente)
    block_key = "rate:block:#{method}:#{sanitize_key(path)}:#{sanitize_key(ip)}"
    if Rails.cache.read(block_key)
      return [429, { 
        'Content-Type' => 'application/json', 
        'Retry-After' => period.to_s,
        'X-RateLimit-Limit' => max_attempts.to_s,
        'X-RateLimit-Remaining' => '0'
      }, [{ status: 429, error: 'Muitas tentativas. Tente novamente em 1 minuto.' }.to_json]]
    end
    
    # Contar tentativas
    limit_key = "rate:count:#{method}:#{sanitize_key(path)}:#{sanitize_key(ip)}"
    count = Rails.cache.fetch(limit_key, expires_in: period) { 0 }
    count += 1
    Rails.cache.write(limit_key, count, expires_in: period)
    
    headers = {
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => max_attempts.to_s,
      'X-RateLimit-Remaining' => [max_attempts - count, 0].max.to_s
    }
    
    # Se excedeu o limite, bloqueia
    if count > max_attempts
      Rails.cache.write(block_key, true, expires_in: period)
      headers['Retry-After'] = period.to_s
      return [429, headers, [{ status: 429, error: 'Muitas tentativas. Tente novamente em 1 minuto.' }.to_json]]
    end
    
    # Continua para o próximo middleware/controller
    status, response_headers, body = @app.call(env)
    
    # Adiciona headers de rate limit na resposta
    response_headers['X-RateLimit-Limit'] = max_attempts.to_s
    response_headers['X-RateLimit-Remaining'] = [max_attempts - count, 0].max.to_s
    
    [status, response_headers, body]
  end
  
  private
  
  # Configura limites por endpoint e método HTTP
  def get_rate_limits(path, method)
    case path
    when '/users/sign_in'
      [5, 60]  # 5 tentativas por minuto
    when '/users/confirm/resend'
      [3, 60]  # 3 reenvios por minuto
    when '/passwords'
      [2, 60]  # 2 pedidos de reset por minuto
    when '/users' && method == 'POST'
      [3, 60]  # 3 cadastros por minuto
    else
      nil  # Sem limite para outros endpoints
    end
  end
  
  # Sanitiza chave para Redis (remove chars especiais)
  def sanitize_key(key)
    key.gsub(/[^a-zA-Z0-9_\-]/, '_')[0..63]
  end
end
