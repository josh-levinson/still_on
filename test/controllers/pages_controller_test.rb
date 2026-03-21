require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET /sms renders successfully" do
    get sms_info_path
    assert_response :success
  end

  test "GET /privacy renders successfully" do
    get privacy_path
    assert_response :success
  end

  test "GET /sms is accessible without sign-in" do
    get sms_info_path
    assert_response :success
  end

  test "GET /privacy is accessible without sign-in" do
    get privacy_path
    assert_response :success
  end
end
