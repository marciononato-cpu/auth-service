source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bcrypt", "~> 3.1.7"
gem "rack-cors"
gem "redis", ">= 4.0.1"
gem "jwt"
gem "dotenv-rails"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "omniauth", "~> 2.0"
gem "omniauth-google-oauth2", "~> 1.0"
gem "omniauth-apple", "~> 1.4"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :production do
  gem "kamal", require: false
  gem "thruster", require: false
end
