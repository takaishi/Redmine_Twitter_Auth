require 'oauth'

class TwitauthController < AccountController
  unloadable

  CONSUMER_KEY = "e9jSWQ0qJQCJA2Qz9imA"
  CONSUMER_SECRET = "keH4d6uN7gTblrIjIyKnJHy5PeK5NifBk11tRBkpM"

  @@callback_url = 'http://localhost:3000/twitauth/access_token'

  def oauth_consumer
    consumer = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET, :site => "http://twitter.com")
  end
  
  def login
    puts request.host_with_port
    consumer = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET, :site => "http://twitter.com")
    request_token = consumer.get_request_token(:oauth_callback => @@callback_url)
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    redirect_to request_token.authorize_url
  end

  def access_token
    request_token = OAuth::RequestToken.new(oauth_consumer, session[:request_token], session[:request_token_secret])
    access_token = request_token.get_access_token({ }, :oauth_token => params[:oauth_token], :oauth_verifier => params[:oauth_verifier])
    twit_successful_authentication(access_token.params[:screen_name])
  end

  def twit_successful_authentication(login)
    user = User.new()
    user = User.find_by_login(login)
    user.login = login
    user.language = Setting.default_language
    if user.save
      user.reload
      logger.info("User '#{user.login}' created from external auth source: #{user.auth_source.type} - #{user.auth_source.name}") if logger && user.auth_source
    end
    user.update_attribute(:last_login_on, Time.now) if user && !user.new_record?
    # Valid user
    self.twit_logged_user = user
    # generate a key and set cookie if autologin
    if params[:autologin] && Setting.autologin?
      token = Token.create(:user => user, :action => 'autologin')
      cookies[:autologin] = { :value => token.value, :expires => 1.year.from_now }
    end
    call_hook(:controller_account_success_authentication_after, {:user => user })
    redirect_back_or_default :controller => 'my', :action => 'page'
  end

  def twit_logged_user=(user)
    reset_session
    if user && user.is_a?(User)
      User.current = user
      session[:user_id] = user.id
    else
      User.current = User.anonymous
    end
  end

end
