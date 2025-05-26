class CalendarEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event, except: [:media_status]

  def bot_time
    if @event.update(bot_time: params[:calendar_event][:bot_time])
      redirect_to upcoming_path(date: @event.date), notice: 'Bot join time updated.'
    else
      redirect_to upcoming_path(date: @event.date), alert: 'Failed to update bot join time.'
    end
  end

  def toggle_bot
    if @event.update(bot_join: params[:calendar_event][:bot_join], bot_time: params[:calendar_event][:bot_time])
      respond_to do |format|
        format.html { redirect_to upcoming_path(date: @event.date), notice: 'Notetaker updated.' }
        format.json { render json: { success: true, bot_join: @event.bot_join, bot_time: @event.bot_time } }
      end
    else
      respond_to do |format|
        format.html { redirect_to upcoming_path(date: @event.date), alert: 'Failed to update notetaker.' }
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  def join_and_schedule_bot
    # Handle immediate bot join if bot_time is 0 or nil
    if @event.bot_time.nil? || @event.bot_time.to_i == 0
      Rails.logger.info "Bot time is 0 or nil, attempting immediate bot join"
      if @event.bot_join && @event.recall_bot_id.nil?
        Rails.logger.info "Attempting to create bot immediately for meeting URL: #{@event.meeting_url}"
        response = RecallService.create_bot(@event.meeting_url)
        Rails.logger.info "Recall service response: #{response.inspect}"
        if response['id'].present?
          @event.update!(recall_bot_id: response['id'])
          Rails.logger.info "Bot created successfully with ID: #{response['id']}"
        else
          Rails.logger.error "Failed to create bot. Response: #{response.inspect}"
        end
      end
    else
      # Start the timer in the background before Google Auth
      wait_seconds = (@event.bot_time.to_i.minutes - 15.seconds).to_i
      Rails.logger.info "Starting bot timer for #{wait_seconds} seconds"
      Rails.logger.info "Bot settings - bot_join: #{@event.bot_join}, bot_time: #{@event.bot_time}, recall_bot_id: #{@event.recall_bot_id}"
      
      Thread.new do
        Rails.logger.info "Timer started, waiting #{wait_seconds} seconds"
        sleep(wait_seconds)
        Rails.logger.info "Timer completed, checking conditions for bot join"
        Rails.logger.info "Current bot settings - bot_join: #{@event.bot_join}, recall_bot_id: #{@event.recall_bot_id}"
        
        if @event.bot_join && @event.recall_bot_id.nil?
          Rails.logger.info "Attempting to create bot for meeting URL: #{@event.meeting_url}"
          response = RecallService.create_bot(@event.meeting_url)
          Rails.logger.info "Recall service response: #{response.inspect}"
          if response['id'].present?
            @event.update!(recall_bot_id: response['id'])
            Rails.logger.info "Bot created successfully with ID: #{response['id']}"
          else
            Rails.logger.error "Failed to create bot. Response: #{response.inspect}"
          end
        else
          Rails.logger.info "Bot not created because: bot_join=#{@event.bot_join}, recall_bot_id=#{@event.recall_bot_id}"
        end
      end
    end

    # Handle redirection based on meeting type
    if @event.meeting_url.include?('zoom.us')
      redirect_to @event.meeting_url, allow_other_host: true
    elsif @event.meeting_url.include?('meet.google.com')
      session[:pending_meeting_url] = @event.meeting_url
      redirect_to '/auth/google_oauth2?prompt=select_account'
    else
      redirect_to @event.meeting_url, allow_other_host: true
    end
  end

  def media_status
    event = CalendarEvent.find(params[:id])
    unless event.user == current_user
      render json: { error: 'Not authorized' }, status: :unauthorized
      return
    end
    
    media_available = event.recall_transcript.present? && event.recall_video_url.present?
    
    render json: {
      media_available: media_available,
      video_url: event.recall_video_url,
      has_transcript: event.recall_transcript.present?
    }
  end

  private

  def proceed_with_joining
    redirect_to @event.meeting_url, allow_other_host: true
  end

  def set_event
    @event = CalendarEvent.find(params[:id])
    unless @event.user == current_user
      redirect_to root_path, alert: 'Not authorized.'
    end
  end
end 