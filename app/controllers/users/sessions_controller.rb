class Users::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  rescue_from ActionController::ParameterMissing do |e|
    render json: { errors: [e.message] }, status: :bad_request
  end

  def create
    user = User.find_by(email: sign_in_params[:email])

    if user.nil?
      # Mensagem genérica pra não enumerar emails
      return render json: { errors: ['Credenciais inválidas'] }, status: :unauthorized
    end

    if user.authenticated?(sign_in_params[:password])
      # Se o email ainda não foi confirmado, bloqueia o login
      if user.confirmed_at.blank?
        return render json: {
          error: 'email_not_confirmed',
          message: 'Seu email ainda não foi confirmado. Verifique sua caixa de entrada ou peça um novo código.',
          resend_code_available: true
        }, status: :forbidden
      end

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

  def destroy
    token = request.headers['Authorization']&.split&.last
    if token
      # Denylist via Redis
      begin
        redis = Redis.new(host: ENV.fetch('REDIS_HOST', '127.0.0.1'), port: ENV.fetch('REDIS_PORT', 6379).to_i)
        redis.set("jwt:blacklist:#{token}", "1", ex: 86400)
      rescue
        # Redis não disponível, logout continua
      end
    end
    render json: { message: 'Logout realizado com sucesso.' }, status: :ok
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
    JWT.encode(payload, JWT_CONFIG[:secret_key], JWT_CONFIG[:algorithm])
  end
end
