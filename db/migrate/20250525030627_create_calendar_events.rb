class CreateCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :calendar_events do |t|
      t.string :title, null: true
      t.string :unique_id, null: false
      t.datetime :start_time, null: true
      t.datetime :end_time, null: true
      t.string :date, null: true
      t.string :start_time_24h, null: true
      t.string :end_time_24h, null: true
      t.string :organizer, null: true
      t.text :description, null: true
      t.text :attendees, null: true
      t.string :google_calendar_link, null: true
      t.string :location, null: true
      t.string :hangout_link, null: true
      t.integer :bot_time, null: true
      t.boolean :bot_join, default: true, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_events, :unique_id, unique: true
  end
end
