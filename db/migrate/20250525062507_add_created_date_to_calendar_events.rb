class AddCreatedDateToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :calendar_events, :created_date, :datetime
  end
end
