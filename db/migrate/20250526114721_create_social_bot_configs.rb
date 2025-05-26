class CreateSocialBotConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :social_bot_configs do |t|
      t.integer :facebook, default: 0
      t.integer :linkedin, default: 0

      t.timestamps
    end
  end
end
