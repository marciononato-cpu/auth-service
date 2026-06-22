class UserMailer < ApplicationMailer
  default from: ENV.fetch('EMAIL_FROM', 'labonosp@gmail.com')

  def confirmation_code(user)
    @user = user
    @code = user.confirmation_code
    @subject = "Seu código de confirmação - LABONO"
    
    # Determinar destinatários
    recipients = [@user.email]
    recipients << @user.backup_email if @user.backup_email.present?
    
    mail(
      to: recipients.join(', '),
      subject: @subject
    )
  end

  def reset_password(user, token)
    @user = user
    @token = token
    @subject = "Solicitação de redefinição de senha - LABONO"
    
    mail(
      to: @user.email,
      subject: @subject
    )
  end
end
