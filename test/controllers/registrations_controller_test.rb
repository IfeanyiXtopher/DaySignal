require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create signs up and redirects to preferences" do
    assert_difference("User.count", 1) do
      post registration_path, params: {
        user: {
          email_address: "newbie@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to edit_preferences_path
    assert cookies[:session_id]
  end
end
