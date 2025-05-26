require "test_helper"

class RecallIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @calendar_event = calendar_events(:test_meeting)
  end

  test "creates a bot for a meeting" do
    # Mock the Recall.ai API response
    mock_response = {
      "id" => "test_bot_123",
      "status_changes" => [
        {
          "code" => "ready",
          "message" => nil,
          "created_at" => Time.current.iso8601
        }
      ]
    }

    # Stub the RecallService.create_bot method
    RecallService.stubs(:create_bot).returns(mock_response)

    # Trigger the bot creation
    RecallBotJob.perform_now(@calendar_event.id)

    # Reload the calendar event
    @calendar_event.reload

    # Verify the bot was created and ID was stored
    assert_equal "test_bot_123", @calendar_event.recall_bot_id
  end

  test "retrieves transcript after meeting" do
    # Set up the bot ID
    @calendar_event.update(recall_bot_id: "test_bot_123")

    # Mock the bot status response
    mock_status = {
      "id" => "test_bot_123",
      "status_changes" => [
        {
          "code" => "done",
          "message" => nil,
          "created_at" => Time.current.iso8601
        }
      ],
      "video_url" => "https://recall.ai/video/test_bot_123"
    }

    # Mock the transcript response
    mock_transcript = [
      {
        "words" => [
          {
            "text" => "Hello, this is a test meeting.",
            "start_timestamp" => 0.0,
            "end_timestamp" => 3.0
          }
        ],
        "speaker" => "Test User",
        "speaker_id" => 1
      }
    ]

    # Stub the RecallService methods
    RecallService.stubs(:get_bot_status).returns(mock_status)
    RecallService.stubs(:get_transcript).returns(mock_transcript)

    # Trigger the status check
    RecallBotStatusJob.perform_now(@calendar_event.id)

    # Reload the calendar event
    @calendar_event.reload

    # Verify the transcript and video URL were stored
    assert_equal mock_transcript, @calendar_event.recall_transcript
    assert_equal "https://recall.ai/video/test_bot_123", @calendar_event.recall_video_url
  end

  test "schedules bot to join meeting at correct time" do
    # Calculate expected bot join time
    expected_join_time = @calendar_event.start_time - @calendar_event.bot_time.minutes

    # Verify the job is scheduled
    assert_enqueued_with(
      job: RecallBotJob,
      at: expected_join_time,
      args: [@calendar_event.id]
    )
  end
end 