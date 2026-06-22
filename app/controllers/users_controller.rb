class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def index
    token = request.headers["Authorization"]&.split&.last
    unless token && verify_jwt(token)
      render json: { errors: ["Acesso negado"] }, status: :unauthorized
      return
    end
    
    # Only admins can access user list
    if @current_user["role"] != "admin"
      render json: { errors: ["Acesso negado. Apenas administradores."] }, status: :forbidden
      return
    end
    
    users = User.all.order(created_at: :desc)
    render json: users.select { |u| u.role != "admin" }.map { |u| 
      u.as_json(only: [:id, :email, :role, :created_at], methods: [:confirmed_at])
    }, status: :ok
  end

  def destroy
    token = request.headers["Authorization"]&.split&.last
    unless token && verify_jwt(token)
      render json: { errors: ["Acesso negado"] }, status: :unauthorized
      return
    end
    
    # Only admins can delete users
    if @current_user["role"] != "admin"
      render json: { errors: ["Acesso negado. Apenas administradores."] }, status: :forbidden
      return
    end
    
    user = User.find_by(id: params[:id])
    unless user
      render json: { errors: ["Usuário não encontrado"] }, status: :not_found
      return
    end
    
    user.destroy
    
    render json: { message: "Usuário #{user.email} removido com sucesso" }, status: :ok
  end

  private

  def verify_jwt(token)
    begin
      decoded = JWT.decode(token, ENV.fetch("JWT_SECRET"), true, { algorithm: "HS256" })
      @current_user = decoded.first
      true
    rescue
      false
    end
  end
end
