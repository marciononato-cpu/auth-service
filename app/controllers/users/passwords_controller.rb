class Users::PasswordsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    user = User.find_by(email: password_params[:email])
    
    if user
      token = SecureRandom.urlsafe_base64(24)
      user.update!(
        reset_password_token: token,
        reset_password_sent_at: Time.current
      )
      UserMailer.reset_password(user, token).deliver_now
    end
    
    # Sempre retornar a mesma mensagem para não vazar emails cadastrados
    render json: { message: 'Se o email existir, você receberá instruções para redefinir sua senha.' }, status: :accepted
  end

  def update
    user = User.find_by(reset_password_token: reset_params[:token])
    
    unless user
      render json: { errors: ['Token inválido ou expirado'] }, status: :unprocessable_entity
      return
    end
    
    if reset_params[:password] != reset_params[:password_confirmation]
      render json: { errors: ['As senhas não coincidem'] }, status: :unprocessable_entity
      return
    end
    
    if reset_params[:password].length < 6
      render json: { errors: ['A senha deve ter pelo menos 6 caracteres'] }, status: :unprocessable_entity
      return
    end
    
    user.update!(
      encrypted_password: BCrypt::Password.create(reset_params[:password], cost: 12),
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
    
    render json: { message: 'Senha redefinida com sucesso! Você pode fazer login agora.' }, status: :ok
  end

  private

  def password_params
    params.require(:password).permit(:email)
  end

  def reset_params
    params.require(:password).permit(:token, :password, :password_confirmation)
  end
end
