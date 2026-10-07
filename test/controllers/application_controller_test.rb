require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "tags Honeybadger errors with the signed-in user's id" do
    user = create_user
    sign_in user

    contexts = []
    Honeybadger.stub(:context, ->(ctx) { contexts << ctx }) do
      get terms_path
    end

    assert_includes contexts, { user_id: user.id }
  end

  test "does not set Honeybadger context for anonymous visitors" do
    contexts = []
    Honeybadger.stub(:context, ->(ctx) { contexts << ctx }) do
      get terms_path
    end

    assert_empty contexts.select { |ctx| ctx.key?(:user_id) }
  end
end
