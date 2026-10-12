# Single-location alert preferences for the signed-in user (MVP: one location).
class PreferencesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    @user.assign_attributes(preference_params)

    if @user.save(context: :preferences_update)
      redirect_to root_path, notice: "Preferences saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def preference_params
    params.require(:user).permit(
      :location_label,
      :latitude,
      :longitude,
      :timezone,
      :alert_time,
      :rain_threshold,
      :alerts_enabled
    )
  end
end
