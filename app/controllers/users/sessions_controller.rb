class Users::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    user = User.find_by(email: sign_in_params[:email])
    
    if user&.authenticated?(sign_in_params[:password])
      token = encode_token(user)
      render json: {
        message: 'Login successful',
        token: token,
        user: user.as_json(only: [:id, :email, :role])
      }, status: :ok
    else
      render json: { errors: ['Credenciais inválidas'] }, status: :unauthorized
    end
  end

  private

  def sign_in_params
    params.require(:user).permit(:email, :password)
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
