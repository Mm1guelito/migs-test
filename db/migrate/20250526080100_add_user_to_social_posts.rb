class AddUserToSocialPosts < ActiveRecord::Migration[7.1]
  def change
    add_reference :social_posts, :user, null: true, foreign_key: true
  end
end
