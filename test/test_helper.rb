# frozen_string_literal: true

# Auth test — Minitest nativo do Rails (sem gem de teste)
# Rodar: bundle exec rails test test/requests/auth_test.rb

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

class ActionDispatch::IntegrationTest
  setup do
    # Limpa o Redis antes de cada teste para evitar vazamento de rate limits
    begin
      [0, 1].each do |db|
        redis = Redis.new(host: '127.0.0.1', port: 6379, db: db)
        redis.scan_each(match: 'rate:*', count: 100).each { |key| redis.del(key) }
        redis.scan_each(match: 'jwt:*', count: 100).each { |key| redis.del(key) }
      end
    rescue
      # Redis indisponível — ignora
    end
  end
end
