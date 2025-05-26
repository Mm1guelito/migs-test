class CreateLinkedinAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :linkedin_accounts do |t|
      # Reference to the main user who owns this account
      t.references :user, null: false, foreign_key: true
      
      # LinkedIn account details
      t.string :email, null: false
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      
      # Additional metadata
      t.string :first_name
      t.string :last_name
      t.string :linkedin_id
      t.string :profile_url
      t.string :headline
      
      # Flag to indicate if this is the primary account
      t.boolean :is_primary, default: false

      t.timestamps
    end

    # Add unique index on email to prevent duplicates
    add_index :linkedin_accounts, :email, unique: true
    add_index :linkedin_accounts, :linkedin_id, unique: true
  end
end 