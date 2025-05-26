# Model for managing additional Google accounts associated with a user
class GoogleAccount < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :calendar_events, dependent: :destroy
  
  # Validations
  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true
  
  # Callbacks
  before_destroy :prevent_primary_account_deletion
  after_save :sync_calendar_events, if: :saved_change_to_calendar_sync_enabled?
  
  # Scopes
  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_primary: false) }
  scope :with_calendar_sync, -> { where(calendar_sync_enabled: true) }
  
  # Instance methods
  
  # Returns the full name of the account owner
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  # Checks if the access token is expired
  # Only considers token expired if the account has been removed from the user
  def token_expired?
    # If the account is still associated with a user, the token is considered valid
    if user.present?
      Rails.logger.info "[GoogleAccount] Token check for #{email}: Valid (account still associated with user)"
      return false
    end
    
    # If the account is not associated with any user, consider the token expired
    Rails.logger.info "[GoogleAccount] Token check for #{email}: Expired (account not associated with any user)"
    true
  end
  
  # Returns a GoogleCalendarService instance for this account
  def calendar_service
    Rails.logger.info "[GoogleAccount] Creating calendar service for #{email} with access_token: #{access_token.present? ? 'present' : 'nil'}, refresh_token: #{refresh_token.present? ? 'present' : 'nil'}"
    GoogleCalendarService.new(access_token, refresh_token)
  end
  
  # Syncs calendar events for this account
  def sync_calendar_events
    return unless calendar_sync_enabled?
    Rails.logger.info "[GoogleAccount] Syncing calendar events for #{email}"
    # Sync events for the next 30 days
    start_date = Time.current
    end_date = 30.days.from_now
    user.sync_calendar_events_for_account(self, start_date, end_date)
  end
  
  private
  
  # Prevents deletion of primary accounts
  def prevent_primary_account_deletion
    if is_primary?
      errors.add(:base, "Cannot delete primary account")
      throw(:abort)
    end
  end
end 