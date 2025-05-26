# Controller for static pages
# Handles the home page and welcome page after authentication
class PagesController < ApplicationController
  # Renders the sign-in page
  def home
  end

  # Show welcome page with user information and calendar events after successful Google authentication
  def welcome
    # Get user information from session
    @user = User.find_by(id: session[:user_id]) if session[:user_id]
    Rails.logger.info "[PagesController] Welcome page - User found: #{@user.present?}"
    
    # Fetch calendar events from all connected accounts
    if @user
      Rails.logger.info "[PagesController] Fetching calendar events for user #{@user.id}"
      @events = @user.all_calendar_events
      Rails.logger.info "[PagesController] Fetched #{@events.size} events"
    else
      @events = []
    end
  end

  # Serve all events as JSON for FullCalendar
  def calendar_events
    user = User.find_by(id: session[:user_id]) if session[:user_id]
    Rails.logger.info "[PagesController] Calendar events request - User found: #{user.present?}"
    
    if user
      start_date = params[:start].present? ? Date.parse(params[:start]) : Date.today.beginning_of_month - 1.month
      end_date = params[:end].present? ? Date.parse(params[:end]) : Date.today.end_of_month + 1.month
      
      Rails.logger.info "[PagesController] Fetching calendar events from #{start_date} to #{end_date} for user #{user.id}"
      
      events = user.all_calendar_events(start_date, end_date)
      formatted_events = events.map { |event|
        {
          id: event.id,
          title: event.title,
          start: event.date,
          end: event.date,
          description: event.description,
          account_id: event.google_account_id,
          account_name: nil,
          unique_id: event.unique_id,
          organizer: event.organizer,
          attendees: event.attendees,
          google_calendar_link: event.google_calendar_link,
          location: event.location,
          hangout_link: event.hangout_link,
          date: event.date,
          start_time_24h: event.start_time_24h,
          end_time_24h: event.end_time_24h,
          recall_bot_id: event.recall_bot_id,
          recall_transcript: event.recall_transcript,
          recall_video_url: event.recall_video_url
        }
      }
      
      Rails.logger.info "[PagesController] Returning #{formatted_events.size} formatted events"
      render json: formatted_events
    else
      Rails.logger.info "[PagesController] No user found, returning empty events array"
      render json: []
    end
  end

  # Settings page - requires authentication
  def settings
    authenticate_user!
  end

  def past_meetings
    @user = User.find_by(id: session[:user_id]) if session[:user_id]
    if @user
      # Events where the user is the owner
      owned = @user.calendar_events.where.not(recall_bot_id: nil).where.not(recall_transcript: nil).where.not(recall_video_url: nil)
      # Events where the user is an attendee (Ruby filter for SQLite)
      attendee = CalendarEvent.where.not(recall_bot_id: nil)
        .where.not(recall_transcript: nil)
        .where.not(recall_video_url: nil)
        .select { |e| e.attendees&.include?(@user.email) }
      # Combine and remove duplicates
      @past_events = (owned + attendee).uniq.sort_by { |e| e.end_time || Time.at(0) }.reverse
    else
      @past_events = []
    end
  end

  def upcoming
    authenticate_user!
    date = params[:date]
    if date.present?
      @events = CalendarEvent.where(user: current_user, date: date)
                            .where('(recall_transcript IS NULL OR recall_video_url IS NULL)')
    else
      @events = []
    end
  end

  def meeting_detail
    @event = CalendarEvent.find(params[:id])
    unless @event.user == current_user || @event.attendees&.include?(current_user.email)
      redirect_to past_meetings_path, alert: 'Not authorized.'
      return
    end

    # Fetch a fresh video URL if recall_bot_id is present
    @recording = nil
    if @event.recall_bot_id.present?
      @recording = RecallService.get_recording(@event.recall_bot_id)
      Rails.logger.debug "[meeting_detail] RecallService.get_recording returned: \n#{@recording.inspect}"
      status = RecallService.get_bot_status(@event.recall_bot_id)
      Rails.logger.debug "[meeting_detail] RecallService.get_bot_status returned: \n#{status.inspect}"
    end

    # Generate social post content for the draft section
    if @event.recall_transcript.present?
      @social_post_content = SocialHelper.generate_post(@event.recall_transcript, platform: 'linkedin')
      
      # Auto-save the generated content if no post exists for this meeting
      unless SocialPost.exists?(user_id: current_user.id, description: @event.id.to_s)
        SocialPost.create!(
          name: 'AI generated',
          platform: 'linkedin',
          content: @social_post_content,
          type: 'generate post',
          user_id: current_user.id,
          description: @event.id.to_s  # Store the meeting ID in description to track which meeting this post belongs to
        )
      end
      
      @existing_social_posts = SocialPost.where(platform: ['linkedin', 'facebook'])
    else
      @social_post_content = nil
      @existing_social_posts = []
    end
  end
end 