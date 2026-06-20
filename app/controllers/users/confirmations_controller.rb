class Users::ConfirmationsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    user = User.find_by(email: confirmation_params[:email])
    
    unless user
      render json: { message: 'Código enviado!' }, status: :accepted
      return
    end

    if user.confirm_with_code(confirmation_params[:code])
      token = encode_token(user)
      render json: {
        message: 'Conta confirmada!',
        token: token,
        user: user.as_json(only: [:id, :email, :role])
      }, status: :ok
    else
      render json: { errors: ['Código incorreto ou expirado'] }, status: :unauthorized
    end
  end

  def resend
    user = User.find_by(email: resend_params[:email])
    
    unless user
      render json: { message: 'Se o email existir, um novo código será enviado.' }, status: :accepted
      return
    end

    if user.confirmed_at.present?
      render json: { message: 'Conta já confirmada.' }, status: :ok
    else
      user.send_confirmation_email
      render json: { message: 'Novo código enviado!' }, status: :accepted
    end
  end

  private

  def confirmation_params
    params.require(:confirmation).permit(:email, :code)
  end

  def resend_params
    params.require(:confirmation).permit(:email)
  end

  def encode_token(user)
    payload = {
      sub: user.id,
      role: user.role,
      exp: Time.now.to_i + 86400
    }
    JWT.encode(payload, ENV.fetch('JWT_SECRET'), 'HS256')
  end
end
