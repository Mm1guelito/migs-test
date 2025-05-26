class SocialBotConfigsController < ApplicationController
  def update
    @config = SocialBotConfig.first_or_create
    if @config.update(bot_config_params)
      redirect_to settings_path, notice: 'Bot timing settings were successfully updated.'
    else
      redirect_to settings_path, alert: 'Failed to update bot timing settings.'
    end
  end

  private

  def bot_config_params
    params.require(:social_bot_config).permit(:facebook, :linkedin)
  end
end 