class AddMeetingUrlToCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :calendar_events, :meeting_url, :string, null: true
  end
end
