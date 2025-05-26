class CreateBotConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :bot_configurations do |t|
      t.string :facebook
      t.string :linkedin
      t.integer :time_interval

      t.timestamps
    end
  end
end
