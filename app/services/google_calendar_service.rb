# Service class to handle Google Calendar API interactions
# This service fetches all calendar events directly from Google Calendar API
require 'google/apis/calendar_v3'
require 'googleauth'

class GoogleCalendarService
  def initialize(access_token, refresh_token = nil)
    @access_token = access_token
    @refresh_token = refresh_token
    Rails.logger.info "[GoogleCalendarService] Initialized with access_token: #{access_token.present? ? 'present' : 'nil'}, refresh_token: #{refresh_token.present? ? 'present' : 'nil'}"
  end

  # Fetches all calendar events (no time range)
  def fetch_events(start_date = nil, end_date = nil)
    client = Google::Apis::CalendarV3::CalendarService.new
    client.authorization = create_authorization

    events = []
    page_token = nil

    time_min = start_date ? start_date.beginning_of_day.iso8601 : nil
    time_max = end_date ? end_date.end_of_day.iso8601 : nil

    begin
      Rails.logger.info "[GoogleCalendarService] Fetching events with time_min: #{time_min}, time_max: #{time_max}"
      result = client.list_events(
        'primary',
        single_events: true,
        order_by: 'startTime',
        page_token: page_token,
        time_min: time_min,
        time_max: time_max,
        time_zone: Time.zone.name,
        fields: 'items(id,summary,start,end,description,organizer,attendees,htmlLink,location,hangoutLink)'
      )
      events.concat(result.items)
      page_token = result.next_page_token
      Rails.logger.info "[GoogleCalendarService] Fetched #{result.items.size} events, next_page_token: #{page_token.present? ? 'present' : 'nil'}"
    end while page_token.present?

    Rails.logger.info "[GoogleCalendarService] Total events fetched: #{events.size}"
    events
  rescue Google::Apis::Error => e
    Rails.logger.error "[GoogleCalendarService] Error fetching calendar events: #{e.message}"
    Rails.logger.error "[GoogleCalendarService] Error details: #{e.to_json}" if e.respond_to?(:to_json)
    []
  end

  private

  attr_reader :access_token, :refresh_token

  def create_authorization
    Rails.logger.info "[GoogleCalendarService] Creating authorization with client_id: #{ENV['GOOGLE_CLIENT_ID'].present? ? 'present' : 'nil'}"
    
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      access_token: access_token,
      refresh_token: refresh_token,
      scope: 'https://www.googleapis.com/auth/calendar.readonly'
    )
    
    # Only attempt token refresh if we have a refresh token
    if refresh_token.present?
      Rails.logger.info "[GoogleCalendarService] Refresh token present, attempting refresh"
      begin
        credentials.refresh!
        Rails.logger.info "[GoogleCalendarService] Token refresh successful"
      rescue => e
        Rails.logger.error "[GoogleCalendarService] Token refresh failed: #{e.message}"
        raise e
      end
    else
      Rails.logger.info "[GoogleCalendarService] No refresh token present, using existing access token"
    end
    
    credentials
  end
end 