class AddDateAnd24hTimesToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:calendar_events, :start_time_24h)
      add_column :calendar_events, :start_time_24h, :string
    end
    
    unless column_exists?(:calendar_events, :end_time_24h)
      add_column :calendar_events, :end_time_24h, :string
    end
  end
end
