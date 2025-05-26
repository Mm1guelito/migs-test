class AddRecallColumnsToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :calendar_events, :recall_bot_id, :string
    add_column :calendar_events, :recall_transcript, :json
    add_column :calendar_events, :recall_video_url, :string
  end
end 