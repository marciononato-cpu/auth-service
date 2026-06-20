class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def index
    token = request.headers["Authorization"]&.split&.last
    unless token && verify_jwt(token)
      render json: { errors: ["Acesso negado"] }, status: :unauthorized
      return
    end
    users = User.all.order(created_at: :desc)
    render json: users.select { |u| u.role != "admin" }.map { |u| 
      u.as_json(only: [:id, :email, :role, :created_at], methods: [:confirmed_at])
    }, status: :ok
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
