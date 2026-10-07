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

  test "GET /terms renders the SMS terms" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms of Service"
    assert_match "reply <strong>STOP</strong>", response.body
  end

  test "footer links to the terms" do
    get privacy_path
    assert_select "footer a[href=?]", terms_path
  end
end
