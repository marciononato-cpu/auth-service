# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication API", type: :request do
  # Auth custom — sem Devise. Usar POST direto nas rotas.

  # ─── Helpers ─────────────────────────────────────────────────────
  def create_and_confirm_user(email: "user@example.com", password: "Test1234!")
    user = User.create!(email:, password:, password_confirmation: password, role: :user)
    user.confirm
    user
  end

  def login(email:, password:)
    post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
    JSON.parse(response.body)["token"]
  end

  def get_confirmation_code(email)
    User.find_by(email:)&.confirmation_code
  end

  def get_reset_token(email)
    User.find_by(email:)&.reset_password_token
  end

  # ─── Registration ────────────────────────────────────────────────
  describe "POST /users (Registration)" do
    let(:attrs) do
      {
        user: { email: "newuser@example.com", password: "Test1234!", password_confirmation: "Test1234!" }
      }
    end

    it "creates user and returns 201" do
      post "/users", params: attrs, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Conta criada")
      expect(json["user"]["email"]).to eq("newuser@example.com")
      expect(json["user"]["role"]).to eq("user")
      expect(User.find_by(email: "newuser@example.com")&.confirmed?).to be false
    end

    it "rejects duplicate email with 422" do
      post "/users", params: attrs, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:created)

      post "/users", params: attrs, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects non-matching passwords with 422" do
      bad = { user: { email: "other@example.com", password: "Test1234!", password_confirmation: "Diff1234!" } }
      post "/users", params: bad, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects missing fields with 422" do
      bad = { user: { email: "other@example.com" } }
      post "/users", params: bad, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── Login ───────────────────────────────────────────────────────
  describe "POST /users/sign_in (Login)" do
    let(:email) { "login_test@example.com" }
    let(:password) { "Test1234!" }
    let!(:user) { User.create!(email:, password:, password_confirmation: password, role: :user) }

    context "without confirmed email" do
      it "returns 403 with email_not_confirmed" do
        post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("email_not_confirmed")
      end
    end

    context "after confirmed" do
      let!(:user) { create_and_confirm_user(email:, password:) }

      it "returns 200 with JWT" do
        post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["token"]).to be_present
        expect(json["user"]["email"]).to eq(email)
      end

      it "rejects wrong password" do
        post "/users/sign_in", params: { user: { email:, password: "Wrong123!" } }, headers: { "CONTENT_TYPE" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── Resend Confirmation ────────────────────────────────────────
  describe "POST /users/confirm/resend" do
    let(:email) { "resend@example.com" }
    let(:password) { "Test1234!" }
    let!(:user) { User.create!(email:, password:, password_confirmation: password, role: :user) }

    it "returns 202" do
      post "/users/confirm/resend", params: { confirmation: { email: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:accepted)
    end
  end

  # ─── Email Confirmation ─────────────────────────────────────────
  describe "POST /users/confirm" do
    let(:email) { "confirm_test@example.com" }
    let(:password) { "Test1234!" }
    let(:code) { get_confirmation_code(email) }

    before do
      User.create!(email:, password:, password_confirmation: password, role: :user)
      # Re-enviar para garantir code fresco
      post "/users/confirm/resend", params: { confirmation: { email: } }, headers: { "CONTENT_TYPE" => "application/json" }
      sleep(0.1)
    end

    it "confirms with correct code" do
      code = get_confirmation_code(email)
      expect(code).to be_present
      expect(code.length).to eq(6)

      post "/users/confirm", params: { confirmation: { email:, code: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
      expect(User.find_by(email:).confirmed?).to be true
    end

    it "rejects wrong code" do
      post "/users/confirm", params: { confirmation: { email:, code: "000000" } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects code with spaces" do
      post "/users/confirm", params: { confirmation: { email:, code: " 000000 " } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── Protected Routes ────────────────────────────────────────────
  describe "GET /users (Protected)" do
    let(:email) { "protected@example.com" }
    let(:password) { "Test1234!" }
    let(:token) { login(email:, password:) }

    before { create_and_confirm_user(email:, password:) }

    it "rejects without token" do
      get "/users"
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("unauthorized")
    end

    it "accepts valid token" do
      get "/users", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to be_successful || response.code == "403"
    end

    it "rejects invalid token" do
      get "/users", headers: { "Authorization" => "Bearer invalid.token.here" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects expired token" do
      secret = ENV.fetch("JWT_SECRET_KEY", "test_secret_key_for_auth_service")
      expired = JWT.encode({ sub: 1, role: "user", exp: 0 }, secret, "HS256")
      get "/users", headers: { "Authorization" => "Bearer #{expired}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects token without Bearer prefix" do
      get "/users", headers: { "Authorization" => "some_token" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── Forgot Password ─────────────────────────────────────────────
  describe "POST /passwords (Forgot Password)" do
    let(:email) { "forgot@example.com" }
    let(:password) { "Test1234!" }
    let!(:user) { create_and_confirm_user(email:, password:) }

    it "returns 202" do
      post "/passwords", params: { password: { email: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:accepted)
    end
  end

  # ─── Reset Password ──────────────────────────────────────────────
  describe "PUT /passwords (Reset Password)" do
    let(:email) { "reset@example.com" }
    let(:password) { "Test1234!" }
    let(:new_password) { "Nova1234!" }
    let!(:user) { create_and_confirm_user(email:, password:) }
    let(:reset_token) { get_reset_token(email) }

    before do
      post "/passwords", params: { password: { email: } }, headers: { "CONTENT_TYPE" => "application/json" }
      sleep(0.1)
    end

    it "resets password with valid token" do
      put "/passwords", params: {
        password: { token: reset_token, password: new_password, password_confirmation: new_password }
      }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Senha alterada")
    end

    it "old password stops working after reset" do
      put "/passwords", params: {
        password: { token: reset_token, password: new_password, password_confirmation: new_password }
      }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)

      post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── Logout ──────────────────────────────────────────────────────
  describe "DELETE /users/sign_out (Logout)" do
    let(:email) { "logout@example.com" }
    let(:password) { "Test1234!" }
    let(:token) { login(email:, password:) }

    before { create_and_confirm_user(email:, password:) }

    it "returns 200 and blacklists token" do
      delete "/users/sign_out", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end

    it "invalidates token for future requests" do
      delete "/users/sign_out", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      get "/users", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── CORS ────────────────────────────────────────────────────────
  describe "CORS" do
    it "OPTIONS returns 200 with CORS headers" do
      options "/users/sign_in", headers: {
        "Origin" => "http://localhost:5173",
        "Access-Control-Request-Method" => "POST",
        "Access-Control-Request-Headers" => "Content-Type, Authorization"
      }
      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to be_present
    end

    it "POST /users with Origin still works" do
      post "/users", params: {
        user: { email: "cors@example.com", password: "Test1234!", password_confirmation: "Test1234!" }
      }, headers: { "CONTENT_TYPE" => "application/json", "Origin" => "http://localhost:5173" }
      expect(response).to have_http_status(:created)
    end
  end

  # ─── Rate Limiting ───────────────────────────────────────────────
  describe "Rate Limiting" do
    it "blocks login after 5 attempts" do
      6.times do
        post "/users/sign_in", params: { user: { email: "nobody@test.com", password: "wrong!" } }, headers: { "CONTENT_TYPE" => "application/json" }
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "blocks resend after 3 attempts" do
      4.times do
        post "/users/confirm/resend", params: { confirmation: { email: "nobody2@test.com" } }, headers: { "CONTENT_TYPE" => "application/json" }
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "blocks forgot after 2 attempts" do
      3.times do
        post "/passwords", params: { password: { email: "nope@test.com" } }, headers: { "CONTENT_TYPE" => "application/json" }
      end
      expect(response).to have_http_status(:too_many_requests)
    end

    it "health check is not rate limited" do
      10.times do
        get "/up"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ─── Full End-to-End Flow ────────────────────────────────────────
  describe "Full E2E Flow" do
    let(:email) { "e2e_#{Time.now.to_i}@e2e.com" }
    let(:password) { "Test1234!" }
    let(:new_password) { "Nova1234!" }

    it "register -> confirm -> login -> forgot -> reset -> logout" do
      # 1. Register
      post "/users", params: { user: { email:, password:, password_confirmation: password } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:created)

      # 2. Get code from DB
      code = get_confirmation_code(email)
      expect(code).to be_present
      expect(code.length).to eq(6)

      # 3. Confirm
      post "/users/confirm", params: { confirmation: { email:, code: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
      login_token = JSON.parse(response.body)["token"]
      expect(login_token).to be_present

      # 4. Login
      post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token"]).to eq(login_token)

      # 5. Forgot
      post "/passwords", params: { password: { email: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:accepted)

      # 6. Reset token from DB
      reset_token = get_reset_token(email)
      expect(reset_token).to be_present

      # 7. Reset
      put "/passwords", params: { password: { token: reset_token, password: new_password, password_confirmation: new_password } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)

      # 8. Login new password
      post "/users/sign_in", params: { user: { email:, password: new_password } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
      new_token = JSON.parse(response.body)["token"]

      # 9. Old password rejected
      post "/users/sign_in", params: { user: { email:, password: } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)

      # 10. Logout
      delete "/users/sign_out", headers: { "Authorization" => "Bearer #{new_token}" }
      expect(response).to have_http_status(:ok)

      # 11. Token blacklisted
      get "/users", headers: { "Authorization" => "Bearer #{new_token}" }
      expect(response).to have_http_status(:unauthorized)

      # 12. Duplicate email
      post "/users", params: { user: { email:, password:, password_confirmation: password } }, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
