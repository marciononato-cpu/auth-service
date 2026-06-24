# Middleware stack — centralizado aqui porque precisa do Rails.application já carregado
# Ordem de processamento (de cima pra baixo):
#   1. CorsMiddleware — bloqueia OPTIONS de origens não permitidas (403) + adiciona headers CORS
#   2. RateLimitingMiddleware — protege endpoints sensíveis (429 se exceder)
#   3. AuthMiddleware — autentica JWT em rotas protegidas (401 se inválido)

# Carregar middlewares customizados explicitamente
require Rails.root.join('app/lib/rate_limiting_middleware')
require Rails.root.join('lib/auth_middleware')
require Rails.root.join('lib/cors_middleware')

# --- CORS Security (primeiro, antes de tudo) ---
# Bloqueia OPTIONS de origens NÃO permitidas e adiciona headers CORS
Rails.application.config.middleware.insert_before 0, CorsMiddleware

# --- Rate Limiting (depois do CORS) ---
Rails.application.config.middleware.insert_after CorsMiddleware, RateLimitingMiddleware

# --- JWT Auth (depois do rate limiter) ---
Rails.application.config.middleware.insert_after RateLimitingMiddleware, AuthMiddleware
