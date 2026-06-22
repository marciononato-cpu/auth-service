class Admin::PasswordsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def initiate
    # Recebe o email do admin que quer trocar a senha
    email = params[:email]&.downcase
    
    unless email && email == ENV.fetch('ADMIN_EMAIL')
      # Mensagem genérica para não vazar que o email existe ou não
      render json: { message: 'Se o email existir, você receberá instruções.' }, status: :accepted
      return
    end

    user = User.find_by(email: email, role: :admin)
    return unless user

    # Gera dois códigos de 6 dígitos
    code1 = rand(100000..999999).to_s
    code2 = rand(100000..999999).to_s

    # Salva os códigos temporariamente (expiram em 15 minutos)
    user.update!(
      admin_reset_code1: code1,
      admin_reset_code2: code2,
      admin_reset_sent_at: Time.current
    )

    # Dispara os dois emails
    AdminResetMailer.admin_reset(user, code1, code2).deliver_now

    render json: { 
      message: 'Códigos enviados para ambos os emails do administrador.',
      emails: [ENV.fetch('ADMIN_EMAIL'), ENV['ADMIN_BACKUP_EMAIL'] || 'marciornonato@gmail.com'].join(', ')
    }, status: :accepted
  end

  def reset
    # Recebe os dois códigos e a nova senha
    email = params[:password][:email]&.downcase
    code1 = params[:password][:code1]
    code2 = params[:password][:code2]
    password = params[:password][:password]
    password_confirmation = params[:password][:password_confirmation]

    unless email && email == ENV.fetch('ADMIN_EMAIL')
      render json: { errors: ['Operação não permitida'] }, status: :unauthorized
      return
    end

    user = User.find_by(email: email, role: :admin)
    
    unless user && user.admin_reset_code1 && user.admin_reset_code2
      render json: { errors: ['Solicitação inválida. Solicite uma nova troca de senha.'] }, status: :unprocessable_entity
      return
    end

    # Verifica expiração (15 minutos)
    if user.admin_reset_sent_at < 15.minutes.ago
      user.update!(admin_reset_code1: nil, admin_reset_code2: nil, admin_reset_sent_at: nil)
      render json: { errors: ['Códigos expirados. Solicite uma nova troca de senha.'] }, status: :unprocessable_entity
      return
    end

    # Verifica os dois códigos
    unless code1 == user.admin_reset_code1 && code2 == user.admin_reset_code2
      render json: { errors: ['Um ou ambos os códigos estão incorretos'] }, status: :unauthorized
      return
    end

    # Valida nova senha
    if password != password_confirmation
      render json: { errors: ['As senhas não conferem'] }, status: :unprocessable_entity
      return
    end

    if password.length < 6
      render json: { errors: ['A senha deve ter pelo menos 6 caracteres'] }, status: :unprocessable_entity
      return
    end

    # Redefine a senha
    user.update!(
      encrypted_password: BCrypt::Password.create(password, cost: 12),
      admin_reset_code1: nil,
      admin_reset_code2: nil,
      admin_reset_sent_at: nil
    )

    render json: { message: 'Senha do administrador redefinida com sucesso!' }, status: :ok
  end
end
