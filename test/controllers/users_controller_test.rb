require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
  end

  # ---- GET /user/edit ----

  test "edit redirects to sign-in when not authenticated" do
    get edit_user_path
    assert_redirected_to onboarding_splash_path
  end

  test "edit renders successfully when signed in" do
    sign_in(@user)
    get edit_user_path
    assert_response :success
  end

  # ---- PATCH /user ----

  test "update redirects to sign-in when not authenticated" do
    patch user_path, params: { user: { first_name: "New" } }
    assert_redirected_to onboarding_splash_path
  end

  test "update saves permitted fields" do
    sign_in(@user)
    patch user_path, params: {
      user: {
        first_name: "Updated",
        last_name: "Name",
        email: "updated@example.com",
        username: "updated_user",
        time_zone: "Eastern Time (US & Canada)"
      }
    }
    assert_redirected_to edit_user_path
    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Name", @user.last_name
    assert_equal "updated@example.com", @user.email
    assert_equal "updated_user", @user.username
    assert_equal "Eastern Time (US & Canada)", @user.time_zone
  end

  test "update sets flash notice on success" do
    sign_in(@user)
    patch user_path, params: { user: { first_name: "Flash" } }
    assert_equal "Profile updated.", flash[:notice]
  end

  test "update re-renders edit on validation failure" do
    other = create_user(email: "taken@example.com")
    sign_in(@user)
    patch user_path, params: { user: { email: other.email } }
    assert_response :unprocessable_entity
  end

  test "update does not allow changing phone_number" do
    original_phone = @user.phone_number
    sign_in(@user)
    patch user_path, params: { user: { phone_number: "+15550000001" } }
    assert_equal original_phone, @user.reload.phone_number
  end
end
