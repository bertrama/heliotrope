# frozen_string_literal: true

class ShibbolethsController < CheckpointController
  def discofeed
    flag = true
    obj_disco_feed = JSON.parse(HTTParty.get("https://heliotrope-testing.hydra.lib.umich.edu/Shibboleth.sso/DiscoFeed").body)
    if flag
      obj_filtered_disco_feed = obj_disco_feed
    else
      obj_filtered_disco_feed = []
      obj_disco_feed.each do |entry|
        obj_filtered_disco_feed << entry if entry["entityID"] == "https://shibboleth.umich.edu/idp/shibboleth"
      end
    end
    render json: obj_filtered_disco_feed
  end

  def help; end

  # This listens on Shibboleth.sso/Login in development mode...
  # When we get here from /shib_login, what typically happens is:
  # 1.  session[:log_me_in] is already set
  # 1.  session[:shib_target] is already set to the real resource
  # 2.  we redirect to target query param (/shib_session)
  # 3.  authenticate_user! will fail, storing the location and redirecting to /login
  # 4.  sessions#new will redirect to authentications#new, giving a dummy login form
  # 5.  authentications#create will set the FAKE_HTTP_X_REMOTE_USER env var and redirect to sessions#new
  # 6.  FakeAuthHeader middleware will set REMOTE_USER from the env var
  # 7.  sessions#new will call authenticate_user!
  # 8.  the Keycard strategy picks up the log_me_in flag and the REMOTE_USER, succeeding
  # 9.  sessions#new will redirect to the stored location (/shib_session)
  # 10. authenticate_user! will now pass, and redirect to :shib_target
  def new
    redirect_to params[:target] || new_user_session_path
  end
end
