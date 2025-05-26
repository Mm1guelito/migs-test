class SocialPostConfigsController < ApplicationController
  before_action :authenticate_user!

  def create
    @social_post = SocialPost.new(social_post_params)
    @social_post.user_id = current_user.id
    @social_post.content = params[:social_post][:example] # Use the example field as content

    if @social_post.save
      redirect_to meeting_detail_path(params[:meeting_id]), notice: 'Post was successfully created.'
    else
      redirect_to meeting_detail_path(params[:meeting_id]), alert: 'Failed to create post. Please try again.'
    end
  end

  private

  def social_post_params
    params.require(:social_post).permit(:name, :platform, :type, :description)
  end
end 