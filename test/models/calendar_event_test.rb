require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "should have date and 24h time fields" do
    event = calendar_events(:one)
    assert_equal '2025-05-25', event.date
    assert_equal '11:06', event.start_time_24h
    assert_equal '11:06', event.end_time_24h
  end
end
