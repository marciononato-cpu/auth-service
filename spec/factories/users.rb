# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "test@example.com" }
    password { "Test1234!" }
    password_confirmation { "Test1234!" }
    role { :user }

    trait :with_confirmed_email do
      after :create do |user|
        user.confirm
      end
    end

    trait :admin do
      role { :admin }
    end
  end
end
