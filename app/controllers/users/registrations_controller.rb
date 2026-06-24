class Users::RegistrationsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    # Sanitização de input
    email = user_params[:email]&.downcase
    password = user_params[:password]
    password_confirmation = user_params[:password_confirmation]
    backup_email = user_params[:backup_email]&.downcase

    if !email || !password
      render json: { errors: ['Dados incompletos'] }, status: :unprocessable_entity
      return
    end

    if password != password_confirmation
      render json: { errors: ['As senhas não coincidem'] }, status: :unprocessable_entity
      return
    end

    if User.find_by(email: email)
      # Mensagem genérica para não validar existência de emails
      render json: { errors: ['Erro ao criar conta'] }, status: :unprocessable_entity
      return
    end

    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      role: :user
    )

    user.send_confirmation_email
    
    render json: {
      message: 'Conta criada! Verifique seus emails para receber o código de confirmação.',
      user: user.as_json(only: [:id, :email, :role])
    }, status: :created
    
  rescue => e
    # Retorna erro genérico para evitar vazamento de informações
    render json: { errors: ['Erro interno no servidor'] }, status: :internal_server_error
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :backup_email)
  end
end
