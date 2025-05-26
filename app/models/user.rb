# Model for managing users and their associated Google accounts
class User < ApplicationRecord
  # Associations
  has_many :google_accounts, dependent: :destroy
  has_many :linkedin_accounts, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  
  # Validations
  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true
  
  # Callbacks
  after_create :create_primary_account
  
  # Instance methods
  
  # Returns the primary Google account for this user
  def primary_account
    google_accounts.primary.first
  end
  
  # Returns all secondary Google accounts
  def secondary_accounts
    google_accounts.secondary
  end
  
  # Returns the primary LinkedIn account for this user
  def primary_linkedin_account
    linkedin_accounts.primary.first
  end
  
  # Returns all secondary LinkedIn accounts
  def secondary_linkedin_accounts
    linkedin_accounts.secondary
  end
  
  # Returns all accounts with calendar sync enabled
  def accounts_with_calendar_sync
    google_accounts.with_calendar_sync
  end
  
  # Returns all calendar events from all synced accounts
  def all_calendar_events(start_date = nil, end_date = nil)
    # Sync events for all accounts first
    accounts_with_calendar_sync.each do |account|
      sync_calendar_events_for_account(account, start_date, end_date)
    end

    # Now fetch from DB, filter by date if present
    events = calendar_events
    if start_date && end_date
      events = events.where(date: start_date..end_date)
    end
    events.order(:date, :start_time_24h)
  end
  
  # Syncs calendar events for a specific Google account
  def sync_calendar_events_for_account(account, start_date = nil, end_date = nil)
    events = account.calendar_service.fetch_events(start_date, end_date)
    CalendarEvent.sync_from_google_calendar(self, events, account)
  end
  
  private
  
  # Creates a primary account from the user's initial Google authentication
  def create_primary_account
    google_accounts.create!(
      email: email,
      first_name: first_name,
      last_name: last_name,
      google_id: google_id,
      is_primary: true,
      calendar_sync_enabled: true
    )
  end
end
