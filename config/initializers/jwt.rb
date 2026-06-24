# frozen_string_literal: true

# Configuração global do JWT
# Usa HS256 (symmetric key) — seguro e simples
# Segredo lido do ENV['JWT_SECRET']
# Expiração: 24 horas
# Issuer: 'auth-service'

JWT_CONFIG = {
  secret_key: ENV.fetch('JWT_SECRET', 'fallback_for_testing_only'),
  algorithm: 'HS256',
  issuer: 'auth-service',
  expiration: 24.hours
}.freeze
