# syntax=docker/dockerfile:1

# Imagem base Ruby (alinha com .ruby-version)
ARG RUBY_VERSION=3.3.11
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Pacotes base do sistema
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libpq-dev \
      postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="0" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# === Build stage: instala gems e pré-compila ===
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ \
      "${BUNDLE_PATH}"/ruby/*/cache \
      "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copia código e pré-compila bootsnap
COPY . .
RUN bundle exec bootsnap precompile -j 1 --gemfile
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# === Final stage ===
FROM base

# Cria usuário não-root para segurança
RUN groupadd --system --gid 1001 rails && \
    useradd rails --uid 1001 --gid 1001 --create-home --shell /bin/bash

# Cria diretórios com permissões corretas
RUN mkdir -p /rails/tmp /rails/log /rails/storage && \
    chown -R rails:rails /rails/tmp /rails/log /rails/storage

USER 1001:1001

# Copia gems e código da stage de build
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Port padrão do Rails
EXPOSE 3000

# Entry point do Rails (prepara DB e sobe o servidor)
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
