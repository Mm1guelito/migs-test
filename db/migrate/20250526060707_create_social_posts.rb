class CreateSocialPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :social_posts do |t|
      t.string :platform, default: 'linkedin'
      t.text :content

      t.timestamps
    end
  end
end
