class SocialBotConfig < ApplicationRecord
  validates :facebook, :linkedin, 
            presence: true,
            numericality: { 
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 60
            }
end
