# frozen_string_literal: true

require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  # ─── Helpers ─────────────────────────────────────────────────────
  def create_and_confirm_user(email: "user@example.com", password: "Test1234!")
    user = User.create!(email:, password:, password_confirmation: password, role: :user)
    user.send_confirmation_email
    user.reload
    # User model é custom, não usa Devise
    user.confirm_with_code(user.confirmation_code)
    user
  end

  def api_post(path, params:, headers: {}, method: :post)
    json_body = JSON.generate(params)
    default_headers = { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    send method, path, params: json_body, headers: default_headers.merge(headers)
    json = JSON.parse(response.body) rescue {}
    [response.status, json]
  end

  def get_confirmation_code(email)
    User.find_by(email:)&.confirmation_code
  end

  def get_reset_token(email)
    User.find_by(email:)&.reset_password_token
  end

  # ─── Registration ────────────────────────────────────────────────
  def test_creates_user_with_201
    status, json = api_post "/users", params: {
      user: { email: "newuser@example.com", password: "Test1234!", password_confirmation: "Test1234!" }
    }
    assert_equal 201, status
    assert_includes json["message"], "Conta criada"
    assert_equal "newuser@example.com", json["user"]["email"]
    assert_equal "user", json["user"]["role"]
    refute User.find_by(email: "newuser@example.com")&.confirmed_at.present?
  end

  def test_rejects_duplicate_email_with_422
    api_post "/users", params: {
      user: { email: "dup@example.com", password: "Test1234!", password_confirmation: "Test1234!" }
    }
    assert_equal 201, response.status

    api_post "/users", params: {
      user: { email: "dup@example.com", password: "Test1234!", password_confirmation: "Test1234!" }
    }
    assert_equal 422, response.status
  end

  def test_rejects_non_matching_passwords_with_422
    api_post "/users", params: {
      user: { email: "pw@example.com", password: "Test1234!", password_confirmation: "Diff1234!" }
    }
    assert_equal 422, response.status
  end

  def test_rejects_missing_fields_with_422
    api_post "/users", params: { user: { email: "miss@example.com" } }
    assert_equal 422, response.status
  end

  # ─── Login ───────────────────────────────────────────────────────
  def test_rejects_unconfirmed_email_with_403
    user = User.create!(email: "unconfirmed@example.com", password: "Test1234!", password_confirmation: "Test1234!", role: :user)
    status, json = api_post "/users/sign_in", params: {
      user: { email: "unconfirmed@example.com", password: "Test1234!" }
    }
    assert_equal 403, status
    assert_equal "email_not_confirmed", json["error"]
  end

  def test_accepts_confirmed_user_login_with_200
    create_and_confirm_user(email: "login@example.com", password: "Test1234!")
    status, json = api_post "/users/sign_in", params: {
      user: { email: "login@example.com", password: "Test1234!" }
    }
    assert_equal 200, status
    assert json["token"].present?, "Token deve estar presente"
    assert_equal "login@example.com", json["user"]["email"]
  end

  def test_rejects_wrong_password_with_401
    create_and_confirm_user(email: "wrong@example.com", password: "Test1234!")
    status, _json = api_post "/users/sign_in", params: {
      user: { email: "wrong@example.com", password: "WrongPassword!" }
    }
    assert_equal 401, status
  end

  # ─── Resend Confirmation ────────────────────────────────────────
  def test_resend_confirmation_returns_202
    User.create!(email: "resend@example.com", password: "Test1234!", password_confirmation: "Test1234!", role: :user)
    status, _json = api_post "/users/confirm/resend", params: {
      confirmation: { email: "resend@example.com" }
    }
    assert_equal 202, status
  end

  # ─── Email Confirmation ─────────────────────────────────────────
  def test_confirms_user_with_correct_code
    email = "confirm_#{Time.now.to_i}@e2e.com"
    password = "Test1234!"
    User.create!(email:, password:, password_confirmation: password, role: :user)
    api_post "/users/confirm/resend", params: { confirmation: { email: } }

    code = get_confirmation_code(email)
    assert code.present?, "Código deve estar presente"
    assert_equal 6, code.length

    status, json = api_post "/users/confirm", params: { confirmation: { email:, code: } }
    assert_equal 200, status
    assert json["token"].present?, "Token deve estar presente após confirmação"
    assert User.find_by(email:)&.confirmed_at.present?
  end

  def test_rejects_wrong_confirmation_code
    email = "wrong_code@example.com"
    User.create!(email:, password: "Test1234!", password_confirmation: "Test1234!", role: :user)
    api_post "/users/confirm/resend", params: { confirmation: { email: } }

    status, _json = api_post "/users/confirm", params: { confirmation: { email:, code: "000000" } }
    assert_equal 401, status
  end

  def test_rejects_code_with_spaces
    email = "spaces@example.com"
    User.create!(email:, password: "Test1234!", password_confirmation: "Test1234!", role: :user)
    api_post "/users/confirm/resend", params: { confirmation: { email: } }

    status, _json = api_post "/users/confirm", params: { confirmation: { email:, code: " 000000 " } }
    assert_equal 401, status
  end

  # ─── Protected Routes ────────────────────────────────────────────
  def test_get_users_without_token_returns_401
    get "/users"
    assert_equal 401, response.status
    json = JSON.parse(response.body)
    assert_equal "unauthorized", json["error"]
  end

  def test_get_users_with_valid_token
    user = create_and_confirm_user(email: "prot@example.com", password: "Test1234!")
    status, json = api_post "/users/sign_in", params: {
      user: { email: "prot@example.com", password: "Test1234!" }
    }
    assert_equal 200, status
    token = json["token"]

    get "/users", headers: { "Authorization" => "Bearer #{token}" }
    assert response.ok? || response.status == 403
  end

  def test_get_users_with_invalid_token_returns_401
    get "/users", headers: { "Authorization" => "Bearer invalid.token.here" }
    assert_equal 401, response.status
  end

  def test_get_users_with_expired_token_returns_401
    secret = ENV.fetch("JWT_SECRET_KEY", "test_secret_key_for_auth_service")
    expired = JWT.encode({ sub: 1, role: "user", exp: 0 }, secret, "HS256")
    get "/users", headers: { "Authorization" => "Bearer #{expired}" }
    assert_equal 401, response.status
  end

  def test_get_users_without_bearer_prefix_returns_401
    user = create_and_confirm_user(email: "bearer@example.com", password: "Test1234!")
    status, json = api_post "/users/sign_in", params: {
      user: { email: "bearer@example.com", password: "Test1234!" }
    }
    token = json["token"]

    get "/users", headers: { "Authorization" => "some_token" }
    assert_equal 401, response.status
  end

  # ─── Forgot Password ─────────────────────────────────────────────
  def test_forgot_password_returns_202
    create_and_confirm_user(email: "forgot@example.com")
    status, _json = api_post "/passwords", params: { password: { email: "forgot@example.com" } }
    assert_equal 202, status
  end

  # ─── Reset Password ──────────────────────────────────────────────
  def test_reset_password_with_valid_token
    email = "reset_#{Time.now.to_i}@e2e.com"
    create_and_confirm_user(email:)

    api_post "/passwords", params: { password: { email: } }
    sleep(0.1)
    reset_token = get_reset_token(email)
    assert reset_token.present?

    status, json = api_post "/passwords", params: {
      password: { token: reset_token, password: "Nova1234!", password_confirmation: "Nova1234!" }
    }, method: :put
    assert_equal 200, status
    assert_includes json["message"], "Senha redefinida"
  end

  # ─── Logout ──────────────────────────────────────────────────────
  def test_logout_blacklists_token
    user = create_and_confirm_user(email: "logout@example.com")
    status, json = api_post "/users/sign_in", params: {
      user: { email: "logout@example.com", password: "Test1234!" }
    }
    token = json["token"]

    delete "/users/sign_out", headers: { "Authorization" => "Bearer #{token}" }
    assert_equal 200, response.status

    get "/users", headers: { "Authorization" => "Bearer #{token}" }
    assert_equal 401, response.status
  end

  # ─── CORS ────────────────────────────────────────────────────────
  def test_cors_preflight_returns_200
    options "/users/sign_in", headers: {
      "Origin" => "http://localhost:5173",
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "Content-Type, Authorization"
    }
    assert_equal 200, response.status
    assert response.headers["Access-Control-Allow-Origin"].present?
  end

  def test_post_with_origin_header
    email = "cors_#{Time.now.to_i}@e2e.com"
    status, _json = api_post "/users", params: {
      user: { email:, password: "Test1234!", password_confirmation: "Test1234!" }
    }, headers: { "Origin" => "http://localhost:5173" }
    assert_equal 201, status
  end

  # ─── Rate Limiting ───────────────────────────────────────────────
  def test_login_rate_limits_after_5_attempts
    6.times do
      api_post "/users/sign_in", params: {
        user: { email: "nobody@test.com", password: "wrong!" }
      }
    end
    assert_equal 429, response.status
  end

  def test_resend_rate_limits_after_3_attempts
    4.times do
      api_post "/users/confirm/resend", params: {
        confirmation: { email: "nobody2@test.com" }
      }
    end
    assert_equal 429, response.status
  end

  def test_forgot_rate_limits_after_2_attempts
    3.times do
      api_post "/passwords", params: {
        password: { email: "nope@test.com" }
      }
    end
    assert_equal 429, response.status
  end

  def test_health_check_not_rate_limited
    10.times do
      get "/up"
      assert_equal 200, response.status
    end
  end

  # ─── Full E2E Flow ───────────────────────────────────────────────
  def test_full_e2e_flow
    email = "e2e_#{Time.now.to_i}@e2e.com"
    password = "Test1234!"
    new_password = "Nova1234!"

    # 1. Register
    status, json = api_post "/users", params: {
      user: { email:, password:, password_confirmation: password }
    }
    assert_equal 201, status

    # 2. Confirm
    code = get_confirmation_code(email)
    assert code.present?
    assert_equal 6, code.length

    status, json = api_post "/users/confirm", params: { confirmation: { email:, code: } }
    assert_equal 200, status
    login_token = json["token"]
    assert login_token.present?

    # 3. Login
    status, json = api_post "/users/sign_in", params: {
      user: { email:, password: }
    }
    assert_equal 200, status
    assert json["token"]

    # 4. Forgot
    status, _json = api_post "/passwords", params: { password: { email: } }
    assert_equal 202, status

    # 5. Reset
    reset_token = get_reset_token(email)
    assert reset_token.present?

    status, _json = api_post "/passwords", params: {
      password: { token: reset_token, password: new_password, password_confirmation: new_password }
    }, method: :put
    assert_equal 200, status

    # 6. Login new password
    status, json = api_post "/users/sign_in", params: {
      user: { email:, password: new_password }
    }
    assert_equal 200, status
    new_token = json["token"]

    # 7. Old password rejected
    api_post "/users/sign_in", params: {
      user: { email:, password: }
    }
    assert_equal 401, response.status

    # 8. Logout
    delete "/users/sign_out", headers: { "Authorization" => "Bearer #{new_token}" }
    assert_equal 200, response.status

    # 9. Token blacklisted
    get "/users", headers: { "Authorization" => "Bearer #{new_token}" }
    assert_equal 401, response.status

    # 10. Duplicate email
    api_post "/users", params: {
      user: { email:, password:, password_confirmation: password }
    }
    assert_equal 422, response.status
  end
end
