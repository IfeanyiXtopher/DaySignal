# Dashboard when signed in; public landing when not.
class HomeController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @user = Current.user
  end
end
