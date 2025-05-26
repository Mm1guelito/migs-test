class SocialPost < ApplicationRecord
  self.inheritance_column = :_type_disabled

  belongs_to :user

  # Attributes
  # platform: string
  # content: text
  # name: string
  # type: string
  # description: text
  # created_at: datetime
  # updated_at: datetime
end
