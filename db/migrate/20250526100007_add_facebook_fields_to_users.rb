class AddFacebookFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :facebook_id, :string
    add_column :users, :facebook_email, :string
    add_column :users, :facebook_token, :string
    add_column :users, :facebook_token_expires_at, :datetime
  end
end
