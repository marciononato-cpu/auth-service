Rails.application.configure do
  config.action_mailer.default_url_options = { host: ENV.fetch("DOMAIN_HOST", "localhost"), port: ENV.fetch("DOMAIN_PORT", "3000") }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_HOST", "smtp.gmail.com"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: "gmail.com",
    user_name: ENV.fetch("SMTP_USER"),
    password: ENV.fetch("SMTP_PASS"),
    authentication: "plain",
    enable_starttls_auto: true,
    open_timeout: 5,
    read_timeout: 5
  }
end
