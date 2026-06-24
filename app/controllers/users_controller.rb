class UsersController < ApplicationController
  # Não precisa mais de skip_before_action — o AuthMiddleware já cuida disso
  # e rotas públicas são definidas no middleware também.
  
  # GET /users — lista usuários (admin apenas)
  def index
    return render json: { errors: ['Acesso negado'] }, status: :forbidden unless admin?
    
    users = User.all.order(created_at: :desc)
    render json: users.select { |u| u.role != 'admin' }.map { |u|
      u.as_json(only: [:id, :email, :role, :created_at], methods: [:confirmed_at])
    }, status: :ok
  end

  # DELETE /users/:id — remove usuário (admin apenas)
  def destroy
    return render json: { errors: ['Acesso negado'] }, status: :forbidden unless admin?
    
    user = User.find_by(id: params[:id])
    unless user
      return render json: { errors: ['Usuário não encontrado'] }, status: :not_found
    end
    
    user.destroy
    render json: { message: "Usuário #{user.email} removido com sucesso" }, status: :ok
  end

  private
  
  def current_user_id
    request.env['auth_user_id']
  end
  
  def current_user_role
    request.env['auth_role']
  end
  
  def admin?
    current_user_role == 'admin'
  end
end
