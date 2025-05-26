# Model for managing LinkedIn accounts associated with a user
class LinkedinAccount < ApplicationRecord
  # Associations
  belongs_to :user
  
  # Validations
  validates :email, presence: true, uniqueness: true
  validates :linkedin_id, presence: true, uniqueness: true
  
  # Callbacks
  before_destroy :prevent_primary_account_deletion
  
  # Scopes
  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_primary: false) }
  
  # Instance methods
  
  # Returns the full name of the account owner
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  # Checks if the access token is expired
  def token_expired?
    return false if user.present?
    true
  end
  
  private
  
  def prevent_primary_account_deletion
    if is_primary?
      errors.add(:base, "Cannot delete primary account")
      throw(:abort)
    end
  end
end 