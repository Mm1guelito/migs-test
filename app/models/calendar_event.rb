class CalendarEvent < ApplicationRecord
  belongs_to :user
  belongs_to :google_account, optional: true

  validates :unique_id, presence: true, uniqueness: { scope: [:user_id, :google_account_id] }
  validates :bot_join, inclusion: { in: [true, false] }
  validates :user, presence: true
  validates :timezone, presence: true

  # Store attendees as JSON
  serialize :attendees, coder: JSON

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_google_account, ->(google_account) { where(google_account: google_account) }
  scope :upcoming, -> { where('start_time > ?', Time.current) }
  scope :past, -> { where('end_time < ?', Time.current) }

  # Extract meeting URL with priority: Google Meet > Zoom > Teams
  def self.extract_meeting_url(event)
    # Check hangout_link first (Google Meet)
    return event.hangout_link if event.hangout_link.present?

    # Check location and description for Zoom or Teams links
    text_to_search = [event.location, event.description].compact.join(' ')
    
    # Look for Zoom links
    zoom_match = text_to_search.match(/https:\/\/[a-z0-9.-]+\.zoom\.us\/(?:j|s)\/\d+(?:\?pwd=[a-zA-Z0-9]+)?/)
    return zoom_match[0] if zoom_match

    # Look for Teams links
    teams_match = text_to_search.match(/https:\/\/teams\.microsoft\.com\/l\/meetup-join\/[a-zA-Z0-9-]+/)
    return teams_match[0] if teams_match

    # Return nil if no meeting URL found
    nil
  end

  # Class method to sync events from Google Calendar
  def self.sync_from_google_calendar(user, events, google_account = nil)
    return unless user.present? && events.present?

    # Process each event
    events.each do |event|
      # Get timezone from event start time
      timezone = event.start&.time_zone || 'UTC'

      # Convert UTC time to event's timezone
      local_start = event.start&.date_time&.in_time_zone(timezone)
      local_end = event.end&.date_time&.in_time_zone(timezone)

      # Prepare event data
      event_data = {
        title: event.summary,
        unique_id: event.id,
        start_time: event.start&.date_time,
        end_time: event.end&.date_time,
        timezone: timezone,
        organizer: event.organizer&.email,
        description: event.description,
        attendees: event.attendees&.map(&:email),
        google_calendar_link: event.html_link,
        location: event.location,
        hangout_link: event.hangout_link,
        bot_time: nil,
        bot_join: true,
        user: user,
        google_account: google_account,
        meeting_url: extract_meeting_url(event),
        # New fields for date and 24-hour time
        date: local_start&.strftime("%Y-%m-%d"),
        start_time_24h: local_start&.strftime("%H:%M"),
        end_time_24h: local_end&.strftime("%H:%M")
      }

      # Find existing event
      existing_event = find_by(unique_id: event.id, user: user, google_account: google_account)

      if existing_event
        # Check if any fields have changed
        changes = {}
        event_data.each do |key, value|
          # Skip user, unique_id, and google_account from comparison
          next if [:user, :unique_id, :google_account].include?(key)
          
          # Compare values, handling nil cases
          if existing_event.send(key) != value
            changes[key] = value
          end
        end

        # Only update if there are changes
        if changes.any?
          existing_event.update!(changes)
          # Schedule Recall bot if meeting URL is present and bot_join is true
          if changes[:meeting_url].present? && existing_event.bot_join
            schedule_recall_bot(existing_event)
          end
        end
      else
        # Create new event if it doesn't exist
        begin
          new_event = create!(event_data)
          # Schedule Recall bot if meeting URL is present and bot_join is true
          if new_event.meeting_url.present? && new_event.bot_join
            schedule_recall_bot(new_event)
          end
        rescue ActiveRecord::RecordNotUnique
          # If we get a unique constraint error, try to find and update the existing event
          existing_event = find_by(unique_id: event.id, user: user)
          if existing_event
            existing_event.update!(event_data.except(:unique_id, :user, :google_account))
            # Schedule Recall bot if meeting URL is present and bot_join is true
            if existing_event.meeting_url.present? && existing_event.bot_join
              schedule_recall_bot(existing_event)
            end
          end
        end
      end
    end
  end

  # Instance method to get start time in the event's timezone
  def start_time_in_timezone
    start_time.in_time_zone(timezone)
  end

  # Instance method to get end time in the event's timezone
  def end_time_in_timezone
    end_time.in_time_zone(timezone)
  end

  before_save :sync_bot_status_with_meeting_url

  private

  def sync_bot_status_with_meeting_url
    # Only sync if bot_join is being changed from nil to true
    if bot_join.nil?
      if meeting_url.blank?
        self.bot_join = false
        self.bot_time = 0
      else
        self.bot_join = true
        self.bot_time = 0 if bot_time.blank? || bot_time.to_i == 0
      end
    end
  end

  def self.schedule_recall_bot(event)
    # Calculate when to send the bot based on bot_time
    bot_send_time = event.start_time - event.bot_time.to_i.minutes
    
    # Only schedule if the meeting hasn't started yet
    if bot_send_time > Time.current
      RecallBotJob.set(wait_until: bot_send_time).perform_later(event.id)
    end
  end
end
