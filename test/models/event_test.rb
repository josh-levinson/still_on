require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @group = create_group(@user)
  end

  # --- validations ---

  test "is valid with required fields" do
    event = create_event(@group, @user)
    assert event.persisted?
  end

  test "is invalid without a title" do
    event = Event.new(group: @group, created_by: @user, recurrence_type: "none")
    assert_not event.valid?
    assert_includes event.errors[:title], "can't be blank"
  end

  test "defaults recurrence_type to none from the database default" do
    event = Event.new(group: @group, created_by: @user, title: "No Cadence")
    assert_equal "none", event.recurrence_type
    assert event.valid?
  end

  test "is invalid with an unknown recurrence_type" do
    event = Event.new(group: @group, created_by: @user, title: "Bad Cadence", recurrence_type: "hourly")
    assert_not event.valid?
    assert_includes event.errors[:recurrence_type], "is not included in the list"
  end

  test "accepts all valid recurrence types" do
    %w[none daily weekly monthly].each do |type|
      event = Event.new(group: @group, created_by: @user, title: "Recurring", recurrence_type: type)
      assert event.valid?, "Expected #{type} to be valid, got: #{event.errors.full_messages}"
    end
  end

  test "quorum must be a positive integer when present" do
    event = Event.new(group: @group, created_by: @user, title: "With Quorum", recurrence_type: "weekly", quorum: 0)
    assert_not event.valid?
    assert_includes event.errors[:quorum], "must be greater than 0"
  end

  test "quorum allows nil" do
    event = create_event(@group, @user, quorum: nil)
    assert event.valid?
  end

  test "quorum must be an integer" do
    event = Event.new(group: @group, created_by: @user, title: "Float Quorum", recurrence_type: "weekly", quorum: 2.5)
    assert_not event.valid?
    assert_includes event.errors[:quorum], "must be an integer"
  end

  # --- scopes ---

  test "active scope returns only active events" do
    active = create_event(@group, @user, is_active: true)
    inactive = Event.create!(group: @group, created_by: @user, title: "Inactive", recurrence_type: "none", is_active: false)

    active_ids = Event.active.pluck(:id)
    assert_includes active_ids, active.id
    assert_not_includes active_ids, inactive.id
  end

  test "recurring scope excludes events with recurrence_type none" do
    none_event = create_event(@group, @user, recurrence_type: "none")
    weekly_event = create_event(@group, @user, recurrence_type: "weekly")

    recurring_ids = Event.recurring.pluck(:id)
    assert_includes recurring_ids, weekly_event.id
    assert_not_includes recurring_ids, none_event.id
  end

  # --- associations ---

  # --- build_schedule / schedule= / next_occurrences ---

  test "build_schedule with daily recurrence sets a daily rule" do
    event = create_event(@group, @user, recurrence_type: "daily")
    event.build_schedule(1.week.from_now)
    event.save!
    assert_not_nil event.schedule
    assert event.schedule.recurrence_rules.any?
  end

  test "build_schedule with monthly and day_of_month option" do
    event = create_event(@group, @user, recurrence_type: "monthly")
    event.build_schedule(1.week.from_now, day_of_month: 15)
    event.save!
    assert_not_nil event.schedule
    assert event.schedule.recurrence_rules.any?
  end

  test "next_occurrences returns upcoming times" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    event.build_schedule(1.week.from_now)
    event.save!
    occurrences = event.next_occurrences(3)
    assert_equal 3, occurrences.length
  end

  test "schedule= setter serializes the IceCube schedule to recurrence_rule" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    s = IceCube::Schedule.new(1.week.from_now)
    s.add_recurrence_rule(IceCube::Rule.weekly)
    event.schedule = s
    assert_not_nil event.recurrence_rule
    assert JSON.parse(event.recurrence_rule).present?
  end

  test "schedule= with nil clears recurrence_rule" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    event.schedule = nil
    assert_nil event.recurrence_rule
  end

  test "next_occurrences returns empty array when event has no schedule" do
    event = create_event(@group, @user, recurrence_type: "none")
    assert_equal [], event.next_occurrences(3)
  end

  test "build_schedule with monthly and nth_weekday option" do
    event = create_event(@group, @user, recurrence_type: "monthly")
    event.build_schedule(1.week.from_now, nth_weekday: { day: :thursday, n: 3 })
    event.save!
    assert_not_nil event.schedule
    assert event.schedule.recurrence_rules.any?
  end

  test "build_schedule with none recurrence_type does not add a rule" do
    event = create_event(@group, @user, recurrence_type: "none")
    s = event.build_schedule(1.week.from_now)
    assert_empty s.recurrence_rules
  end

  test "destroying event destroys its occurrences" do
    event = create_event(@group, @user)
    create_occurrence(event)
    assert_difference "EventOccurrence.count", -1 do
      event.destroy
    end
  end
end
