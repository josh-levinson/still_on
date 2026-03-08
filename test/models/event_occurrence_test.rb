require "test_helper"

class EventOccurrenceTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @group = create_group(@user)
    @event = create_event(@group, @user)
    @occurrence = create_occurrence(@event)
  end

  # --- validations ---

  test "is valid with required fields" do
    assert @occurrence.persisted?
  end

  test "is invalid without start_time" do
    occ = EventOccurrence.new(event: @event, end_time: 1.week.from_now, status: "scheduled")
    assert_not occ.valid?
    assert_includes occ.errors[:start_time], "can't be blank"
  end

  test "is invalid without end_time" do
    occ = EventOccurrence.new(event: @event, start_time: 1.week.from_now, status: "scheduled")
    assert_not occ.valid?
    assert_includes occ.errors[:end_time], "can't be blank"
  end

  test "is invalid without status" do
    occ = EventOccurrence.new(event: @event, start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours, status: nil)
    assert_not occ.valid?
    assert_includes occ.errors[:status], "can't be blank"
  end

  test "is invalid with unknown status" do
    occ = EventOccurrence.new(event: @event, start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours, status: "pending")
    assert_not occ.valid?
    assert_includes occ.errors[:status], "is not included in the list"
  end

  test "accepts all valid statuses" do
    %w[scheduled cancelled completed].each do |s|
      occ = EventOccurrence.new(event: @event, start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours, status: s)
      assert occ.valid?, "Expected #{s} to be valid, got: #{occ.errors.full_messages}"
    end
  end

  test "end_time must be after start_time" do
    start = 1.week.from_now
    occ = EventOccurrence.new(event: @event, start_time: start, end_time: start - 1.minute, status: "scheduled")
    assert_not occ.valid?
    assert_includes occ.errors[:end_time], "must be after start time"
  end

  test "end_time equal to start_time is invalid" do
    t = 1.week.from_now
    occ = EventOccurrence.new(event: @event, start_time: t, end_time: t, status: "scheduled")
    assert_not occ.valid?
    assert_includes occ.errors[:end_time], "must be after start time"
  end

  # --- scopes ---

  test "upcoming scope returns future occurrences in ascending order" do
    past = create_occurrence(@event, start_time: 2.days.ago, end_time: 2.days.ago + 2.hours)
    future_near = create_occurrence(@event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    future_far = create_occurrence(@event, start_time: 2.weeks.from_now, end_time: 2.weeks.from_now + 2.hours)

    upcoming = EventOccurrence.upcoming
    assert_not_includes upcoming, past
    assert upcoming.index(future_near) < upcoming.index(future_far)
  end

  test "past scope returns past occurrences in descending order" do
    older = create_occurrence(@event, start_time: 2.weeks.ago, end_time: 2.weeks.ago + 2.hours)
    newer = create_occurrence(@event, start_time: 3.days.ago, end_time: 3.days.ago + 2.hours)

    past = EventOccurrence.past
    assert_includes past, older
    assert_includes past, newer
    assert past.index(newer) < past.index(older)
  end

  test "scheduled scope returns only scheduled occurrences" do
    cancelled = create_occurrence(@event, status: "cancelled")

    scheduled = EventOccurrence.scheduled
    assert_includes scheduled, @occurrence
    assert_not_includes scheduled, cancelled
  end

  # --- attending_count ---

  test "attending_count sums attending RSVPs including guest_count" do
    create_rsvp(@occurrence, guest_name: "Person A", status: "attending", guest_count: 1)
    create_rsvp(@occurrence, guest_name: "Person B", status: "attending", guest_count: 2)
    create_rsvp(@occurrence, guest_name: "Person C", status: "declined", guest_count: 0)

    # Person A: 1 + 1 = 2, Person B: 1 + 2 = 3, Person C: excluded
    assert_equal 5, @occurrence.attending_count
  end

  test "attending_count returns 0 when no RSVPs" do
    assert_equal 0, @occurrence.attending_count
  end

  # --- full? ---

  test "full? returns false when no max_attendees set" do
    @occurrence.update!(max_attendees: nil)
    assert_not @occurrence.full?
  end

  test "full? returns false when attendance is below max" do
    @occurrence.update!(max_attendees: 10)
    create_rsvp(@occurrence, guest_name: "One Person", status: "attending", guest_count: 0)
    assert_not @occurrence.full?
  end

  test "full? returns true when attendance meets max" do
    @occurrence.update!(max_attendees: 2)
    create_rsvp(@occurrence, guest_name: "Two People", status: "attending", guest_count: 1)
    assert @occurrence.full?
  end

  # --- invite_token / find_by_invite_token ---

  test "invite_token generates a URL-safe token" do
    token = @occurrence.invite_token
    assert_match(/\A[A-Za-z0-9_-]+\z/, token)
  end

  test "find_by_invite_token returns the occurrence" do
    token = @occurrence.invite_token
    found, phone = EventOccurrence.find_by_invite_token(token)
    assert_equal @occurrence.id, found.id
    assert_nil phone
  end

  test "invite_token can encode a phone number" do
    token = @occurrence.invite_token(phone: "+15551234567")
    found, phone = EventOccurrence.find_by_invite_token(token)
    assert_equal @occurrence.id, found.id
    assert_equal "+15551234567", phone
  end

  test "find_by_invite_token returns nil for a tampered token" do
    found, phone = EventOccurrence.find_by_invite_token("not-a-real-token")
    assert_nil found
    assert_nil phone
  end

  test "find_by_invite_token returns nil for empty string" do
    found, phone = EventOccurrence.find_by_invite_token("")
    assert_nil found
    assert_nil phone
  end
end
