class AddUniqueIndexToCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    add_index :calendar_events, [:unique_id, :user_id, :google_account_id], unique: true, name: 'index_calendar_events_on_unique_id_and_user_and_account'
  end
end
