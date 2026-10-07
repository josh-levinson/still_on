require "test_helper"

class ThemesControllerTest < ActionDispatch::IntegrationTest
  test "choosing dark saves the cookie and renders the dark theme" do
    patch theme_path, params: { theme: "dark" }, headers: { "HTTP_REFERER" => privacy_url }

    assert_redirected_to privacy_url
    assert_equal "dark", cookies[:theme]

    get privacy_path
    assert_select "html[data-theme=dark]"
    assert_select "meta[name=theme-color][content='#0f1733']:not([media])"
    assert_select ".theme-option[value=dark][aria-pressed=true]"
    assert_select ".theme-option[value=system][aria-pressed=false]"
  end

  test "choosing light works on the onboarding layout" do
    patch theme_path, params: { theme: "light" }

    assert_redirected_to root_path
    get onboarding_splash_path
    assert_select "html[data-theme=light]"
    assert_select ".onboarding-footer .theme-option[value=light][aria-pressed=true]"
  end

  test "choosing auto clears the cookie and follows the device" do
    patch theme_path, params: { theme: "dark" }
    patch theme_path, params: { theme: "system" }

    assert cookies[:theme].blank?
    get privacy_path
    assert_select "html[data-theme]", count: 0
    assert_select "meta[name=theme-color][media]", count: 2
    assert_select ".theme-option[value=system][aria-pressed=true]"
  end

  test "an unknown cookie value is treated as auto" do
    cookies[:theme] = "neon"

    get privacy_path
    assert_select "html[data-theme]", count: 0
  end
end
