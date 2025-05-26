class RecallBotJob < ApplicationJob
  queue_as :default

  def perform(calendar_event_id)
    calendar_event = CalendarEvent.find(calendar_event_id)
    return unless calendar_event.bot_join && calendar_event.meeting_url.present?

    # Create bot for the meeting
    response = RecallService.create_bot(calendar_event.meeting_url)
    
    if response["id"].present?
      # Store the bot ID in the calendar event
      calendar_event.update(recall_bot_id: response["id"])
      
      # Schedule a job to check the bot status after the meeting
      RecallBotStatusJob.set(wait_until: calendar_event.end_time + 5.minutes)
                        .perform_later(calendar_event_id)
    end
  end
end 