class User < ApplicationRecord
  enum :role, { user: 0, admin: 1 }

  before_create :generate_confirmation_code

  def authenticated?(password)
    return false unless encrypted_password.present?
    BCrypt::Password.new(encrypted_password) == password
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

  def self.authenticate(email, password)
    user = find_by(email: email.downcase)
    user if user&.authenticated?(password)
  end

  private

  def generate_confirmation_code
    self.confirmation_code = rand(100000..999999).to_s
  end
end
