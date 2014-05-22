
class MainController < ApplicationController

  set :views, ['main','application']

  def dispatch(action)
    super(:main,action)
    method(action).call
  end

  #新版未登录首页
  def index

    set_no_cache_header
    halt erb(:index2,layout:false) unless @current_uid
    erb :index
  end

  def global_counts_json
    set_no_cache_header
    tracks, users = $counter_client.getByNames([Settings.counter.tracks, Settings.counter.vusers], 0)
    render_json({tracks: tracks+800000, users: users+2000})
  end

  def error_page
    halt erb_js(:page_error_js) if request.xhr?
    erb :page_error
  end

end
