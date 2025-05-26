require 'httparty'

class CheckRecallStatusJob
  include Sidekiq::Job
  sidekiq_options retry: 5, wait: :polynomially_longer

  # Class method to check all existing calendar events with recall_bot_id
  def self.check_all_pending_events
    CalendarEvent.where.not(recall_bot_id: nil)
                .where(recall_transcript: nil)
                .where(recall_video_url: nil)
                .find_each do |event|
      Rails.logger.info "Scheduling status check for calendar event #{event.id}"
      perform_async(event.id)
    end
  end
  
  def perform(calendar_event_id = nil)
    if calendar_event_id.nil?
      # Check all pending events
      pending_events = CalendarEvent.where.not(recall_bot_id: nil)
                                   .where(recall_transcript: nil, recall_video_url: nil)
                                   .order(created_at: :asc)
      
      Rails.logger.info "Found #{pending_events.count} pending events to check"
      
      pending_events.each do |event|
        Rails.logger.info "Checking event #{event.id} with bot #{event.recall_bot_id}"
        check_event(event)
      end
    else
      # Check specific event
      event = CalendarEvent.find_by(id: calendar_event_id)
      if event
        check_event(event)
      else
        Rails.logger.error "Event #{calendar_event_id} not found"
      end
    end
  end

  private

  def check_event(event)
    Rails.logger.info "get_bot_status: Making API request to https://us-east-1.recall.ai/api/v1/bot/#{event.recall_bot_id}"
    
    begin
      response = RecallService.get_bot_status(event.recall_bot_id)
      Rails.logger.info "API Response for event #{event.id}: #{response.inspect}"
      
      current_status = response.dig('status_changes')&.last&.dig('code')
      
      case current_status
      when 'done'
        begin
          # Get transcript and video URL
          transcript = RecallService.get_transcript(event.recall_bot_id)
          recording = RecallService.get_recording(event.recall_bot_id)
          video_url = recording[:video_url]
          
          if transcript.present? || video_url.present?
            # Update event with available media
            event.update!(
              recall_transcript: transcript,
              recall_video_url: video_url
            )
            Rails.logger.info "Successfully updated event #{event.id} with available media"
          else
            # If no media is available after bot is done, mark as completed
            Rails.logger.info "No media available for event #{event.id} after bot completion"
            event.update!(
              recall_transcript: [],
              recall_video_url: nil
            )
          end
        rescue => e
          Rails.logger.error "Error getting media for event #{event.id}: #{e.message}"
          self.class.perform_in(30.seconds, event.id)
        end
      when 'error', 'fatal'
        error_message = response.dig('status_changes')&.last&.dig('message') || 'Unknown error'
        Rails.logger.error "Bot #{event.recall_bot_id} failed for event #{event.id}. Error: #{error_message}"
        # Don't reschedule for error/fatal states
      when 'call_ended'
        # Call has ended but processing is still happening, wait a bit longer
        self.class.perform_in(30.seconds, event.id)
        Rails.logger.info "Call ended for event #{event.id}, waiting for processing..."
      when 'joining_call', 'in_waiting_room'
        # Bot is still joining or in waiting room, wait a bit longer
        self.class.perform_in(30.seconds, event.id)
        Rails.logger.info "Bot is #{current_status} for event #{event.id}, waiting..."
      else
        # Handle any other status by rescheduling
        Rails.logger.info "Unknown status '#{current_status}' for event #{event.id}, rescheduling check..."
        self.class.perform_in(30.seconds, event.id)
      end
    rescue => e
      Rails.logger.error "Error checking bot status for event #{event.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Reschedule with exponential backoff
      self.class.perform_in(30.seconds, event.id)
    end
  end
end 