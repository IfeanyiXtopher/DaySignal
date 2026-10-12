# Mapbox globe explorer landing + signed-in alert status in the side panel.
class HomeController < ApplicationController
  allow_unauthenticated_access only: :index
  layout "explorer"

  def index
    @user = Current.user
    @mapbox_token = ENV["MAPBOX_ACCESS_TOKEN"].to_s
  end
end
