class SocialPostsController < ApplicationController
  before_action :authenticate_user!

  def create
    params[:social_post][:content] = params[:social_post][:example]
    @social_post = SocialPost.new(social_post_params)
    @social_post.user_id = current_user.id
    
    if @social_post.save
      redirect_to meeting_detail_path(params[:meeting_id]), notice: 'Social post was successfully created.'
    else
      redirect_to meeting_detail_path(params[:meeting_id]), alert: 'Failed to create social post.'
    end
  end

  def update
    @social_post = SocialPost.find(params[:id])
    
    if @social_post.update(social_post_params)
      redirect_to meeting_detail_path(params[:meeting_id]), notice: 'Social post was successfully updated.'
    else
      redirect_to meeting_detail_path(params[:meeting_id]), alert: 'Failed to update social post.'
    end
  end

  def automate
    @event = CalendarEvent.find(params[:meeting_id])
    transcript_text = SocialHelper.concatenate_transcript(@event.recall_transcript)
    requirements = params[:requirements]
    
    @generated_content = SocialHelper.generate_post_from_requirements(transcript_text, requirements)
    
    respond_to do |format|
      format.json { render json: { content: @generated_content } }
    end
  end

  private

  def social_post_params
    params.require(:social_post).permit(:platform, :content, :name, :type, :description)
  end
end 