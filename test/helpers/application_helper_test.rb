require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  setup do
    @organizer  = create_user
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
  end

  test "google_calendar_url includes event title and formatted dates" do
    url = google_calendar_url(@occurrence, @event)
    assert_includes url, "text=Test+Event"
    start_utc = @occurrence.start_time.utc.strftime("%Y%m%dT%H%M%SZ")
    assert_includes url, start_utc
  end

  test "google_calendar_url includes location when present" do
    @occurrence.update!(location: "The Park")
    url = google_calendar_url(@occurrence, @event)
    assert_includes url, "location=The+Park"
  end

  test "google_calendar_url omits location when blank" do
    @occurrence.update!(location: nil)
    url = google_calendar_url(@occurrence, @event)
    assert_not_includes url, "location="
  end

  test "google_calendar_url includes notes as details when present" do
    @occurrence.update!(notes: "Bring chairs")
    url = google_calendar_url(@occurrence, @event)
    assert_includes url, "details=Bring+chairs"
  end

  test "google_calendar_url omits details when notes are blank" do
    @occurrence.update!(notes: nil)
    url = google_calendar_url(@occurrence, @event)
    assert_not_includes url, "details="
  end
end
