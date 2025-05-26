class RecallBotStatusJob < ApplicationJob
  queue_as :default
  
  # Retry up to 5 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  
  def perform(calendar_event_id)
    calendar_event = CalendarEvent.find(calendar_event_id)
    return unless calendar_event.recall_bot_id.present?

    begin
      # Get bot status
      response = RecallService.get_bot_status(calendar_event.recall_bot_id)
      current_status = response.dig('status_changes')&.last&.dig('code')
      
      Rails.logger.info "Bot status for event #{calendar_event_id}: #{current_status}"
      
      case current_status
      when 'done'
        begin
          # Get transcript and video URL
          transcript = RecallService.get_transcript(calendar_event.recall_bot_id)
          video_url = response["video_url"]
          
          if transcript.present?
            # Store transcript and video URL
            calendar_event.update!(
              recall_transcript: transcript,
              recall_video_url: video_url
            )
            Rails.logger.info "Successfully updated transcript and video URL for calendar event #{calendar_event_id}"
          else
            Rails.logger.error "Received empty transcript for event #{calendar_event_id}"
            # Reschedule check in case transcript is still being processed
            self.class.set(wait: 30.seconds).perform_later(calendar_event_id)
          end
        rescue => e
          Rails.logger.error "Error getting transcript for event #{calendar_event_id}: #{e.message}"
          self.class.set(wait: 30.seconds).perform_later(calendar_event_id)
        end
      when 'error', 'fatal'
        error_message = response.dig('status_changes')&.last&.dig('message') || 'Unknown error'
        Rails.logger.error "Bot failed for event #{calendar_event_id}. Error: #{error_message}"
        # Don't reschedule for error/fatal states
      when 'call_ended'
        # Call has ended but processing is still happening, wait a bit longer
        self.class.set(wait: 30.seconds).perform_later(calendar_event_id)
        Rails.logger.info "Call ended for event #{calendar_event_id}, waiting for processing..."
      when 'joining_call', 'in_waiting_room'
        # Bot is still joining or in waiting room, wait a bit longer
        self.class.set(wait: 30.seconds).perform_later(calendar_event_id)
        Rails.logger.info "Bot is #{current_status} for event #{calendar_event_id}, waiting..."
      else
        # Handle any other status by rescheduling
        Rails.logger.info "Unknown status '#{current_status}' for event #{calendar_event_id}, rescheduling check..."
        self.class.set(wait: 30.seconds).perform_later(calendar_event_id)
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Calendar event #{calendar_event_id} not found: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Error processing RecallBotStatusJob for calendar event #{calendar_event_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to trigger retry mechanism
    end
  end
end 