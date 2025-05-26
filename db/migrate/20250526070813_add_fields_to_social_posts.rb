class AddFieldsToSocialPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :social_posts, :name, :string, null: true
    add_column :social_posts, :type, :string, null: true
    add_column :social_posts, :description, :string, null: true
  end
end
