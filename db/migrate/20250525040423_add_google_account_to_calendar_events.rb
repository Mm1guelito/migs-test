class AddGoogleAccountToCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    add_reference :calendar_events, :google_account, null: true, foreign_key: { on_delete: :cascade }
  end
end
