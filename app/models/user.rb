class User < ApplicationRecord
  enum :role, { user: 0, admin: 1 }

  has_secure_password

  before_create :generate_confirmation_code

  # Relacionamento com OAuth
  validates :email, presence: true, uniqueness: { scope: :provider }, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :email_changed?
  validates :provider, presence: true, if: :oauth_provider?
  validates :uid, presence: true, if: :oauth_provider?

  def oauth_provider?
    provider.present? && uid.present?
  end

  def authenticated?(password)
    return false unless password_digest.present?
    BCrypt::Password.new(password_digest) == password
  end

  def confirm_with_code(code)
    if confirmation_code == code
      update!(
        confirmation_code: nil,
        confirmed_at: Time.current,
        code_sent_at: nil
      )
      true
    else
      false
    end
  end

  def send_confirmation_email
    return false if confirmed_at.present? || confirmation_code.nil?
    update!(code_sent_at: Time.current)
    UserMailer.confirmation_code(self).deliver_now
    true
  end

  # Método para autenticar ou criar usuário via OAuth
  def self.find_or_create_from_oauth(provider, uid, auth_hash)
    user = find_by(provider: provider, uid: uid)

    if user
      # Atualiza informações se estiver vazio
      updates = {}
      updates[:name] = auth_hash['info']['name'] if user.name.blank?
      updates[:image] = auth_hash['info']['image'] if user.image.blank?
      updates[:email] = auth_hash['info']['email'] if user.email.blank?
      user.update!(updates) if updates.any?
      user
    else
      # Verifica se já existe email
      existing_user = find_by(email: auth_hash['info']['email']) if auth_hash['info']['email'].present?
      if existing_user
        # Vincula OAuth ao existing user
        existing_user.update!(
          provider: provider,
          uid: uid,
          name: auth_hash['info']['name'],
          image: auth_hash['info']['image'],
          confirmed_at: Time.current
        )
        existing_user
      else
        # Cria novo usuário
        create!(
          email: auth_hash['info']['email'],
          provider: provider,
          uid: uid,
          name: auth_hash['info']['name'],
          image: auth_hash['info']['image'],
          confirmed_at: Time.current,
          password: 'temporary' + rand(99999).to_s
        )
      end
    end
  end

  def self.authenticate(email, password)
    user = find_by(email: email.downcase)
    user if user&.authenticated?(password)
  end

  private

  def generate_confirmation_code
    self.confirmation_code = rand(100000..999999).to_s
  end
end
