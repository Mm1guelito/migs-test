class AddDateAnd24hTimesToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :calendar_events, :start_time_24h, :string
    add_column :calendar_events, :end_time_24h, :string
  end
end
