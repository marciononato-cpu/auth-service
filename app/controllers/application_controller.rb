class ApplicationController < ActionController::API
  # Sanitização global de erros para evitar vazamento de informações
  rescue_from ActionController::UnknownFormat do |e|
    render json: { errors: ['Requisição inválida'] }, status: :bad_request
  end

  rescue_from StandardError do |e|
    # Se for ParameterMissing, deixar os controllers tratarem
    if e.is_a?(ActionController::ParameterMissing)
      raise
    end
    render json: { errors: ['Erro interno no servidor'] }, status: :internal_server_error
  end
end
