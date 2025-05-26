class CreateGoogleAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :google_accounts do |t|
      # Reference to the main user who owns this account
      t.references :user, null: false, foreign_key: true
      
      # Google account details
      t.string :email, null: false
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      
      # Additional metadata
      t.string :first_name
      t.string :last_name
      t.string :google_id
      
      # Flag to indicate if this is the primary account (cannot be removed)
      t.boolean :is_primary, default: false
      
      # Flag to indicate if calendar sync is enabled
      t.boolean :calendar_sync_enabled, default: true

      t.timestamps
    end

    # Add unique index on email to prevent duplicates
    add_index :google_accounts, :email, unique: true
  end
end 