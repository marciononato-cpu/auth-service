class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('EMAIL_FROM', 'marciornonato@gmail.com')
  layout 'mailer'
end
