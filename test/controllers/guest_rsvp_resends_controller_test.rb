require "test_helper"

class GuestRsvpResendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @group = create_group(@organizer)
    @event = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
  end

  # --- new ---

  test "new renders the resend form" do
    get new_guest_rsvp_resend_path
    assert_response :success
  end

  # --- create ---

  test "create sends SMS for each matching upcoming RSVP" do
    create_rsvp(@occurrence, guest_phone: "+15550001111")

    sms_calls = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_calls << { to: to, body: body } }) do
      post guest_rsvp_resend_path, params: { phone: "(555) 000-1111" }
    end

    assert_equal 1, sms_calls.size
    assert_equal "+15550001111", sms_calls.first[:to]
    assert_match @event.title, sms_calls.first[:body]
    assert_redirected_to new_guest_rsvp_resend_path
    assert_match "we'll text you", flash[:notice]
  end

  test "create matches phone numbers in varied formats" do
    create_rsvp(@occurrence, guest_phone: "(555) 000-2222")

    sms_calls = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_calls << to }) do
      post guest_rsvp_resend_path, params: { phone: "5550002222" }
    end

    assert_equal 1, sms_calls.size
  end

  test "create sends nothing and redirects gracefully when no RSVPs found" do
    sms_calls = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_calls << to }) do
      post guest_rsvp_resend_path, params: { phone: "5559999999" }
    end

    assert_equal 0, sms_calls.size
    assert_redirected_to new_guest_rsvp_resend_path
    assert_match "we'll text you", flash[:notice]
  end

  test "create sends nothing for cancelled occurrences" do
    @occurrence.update!(status: "cancelled")
    create_rsvp(@occurrence, guest_phone: "+15550003333")

    sms_calls = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_calls << to }) do
      post guest_rsvp_resend_path, params: { phone: "5550003333" }
    end

    assert_equal 0, sms_calls.size
  end

  test "create sends nothing for past occurrences" do
    past_occurrence = create_occurrence(@event, start_time: 1.day.ago, end_time: 1.day.ago + 2.hours)
    create_rsvp(past_occurrence, guest_phone: "+15550004444")

    sms_calls = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_calls << to }) do
      post guest_rsvp_resend_path, params: { phone: "5550004444" }
    end

    assert_equal 0, sms_calls.size
  end

  test "create redirects gracefully when phone is blank" do
    post guest_rsvp_resend_path, params: { phone: "" }
    assert_redirected_to new_guest_rsvp_resend_path
  end

  test "create continues and logs error when SMS fails" do
    create_rsvp(@occurrence, guest_phone: "+15550005555")

    SmsService.stub(:send_message, ->(**) { raise Twilio::REST::RestError.new("fail", double_twilio_response) }) do
      assert_nothing_raised do
        post guest_rsvp_resend_path, params: { phone: "5550005555" }
      end
    end

    assert_redirected_to new_guest_rsvp_resend_path
  end

  private

  def double_twilio_response
    Struct.new(:status_code, :body).new(500, { "message" => "fail", "code" => 0 })
  end
end
