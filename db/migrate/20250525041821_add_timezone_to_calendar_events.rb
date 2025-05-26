class AddTimezoneToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :calendar_events, :timezone, :string
  end
end
