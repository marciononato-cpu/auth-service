class UserMailer < ApplicationMailer
  def confirmation_code(user)
    @user = user
    @code = user.confirmation_code
    @subject = "Seu código de confirmação"
    
    mail(
      to: @user.email,
      subject: @subject
    )
  end

  def reset_password(user, token)
    @user = user
    @token = token
    @subject = "Solicitação de redefinição de senha"
    
    mail(
      to: @user.email,
      subject: @subject
    )
  end
end
