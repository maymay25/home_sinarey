class WelcomeController < ApplicationController

  set :views, ['welcome','application']

  def dispatch(action)
    super(:welcome,action)
    method(action).call
  end

  def download_page
    erb :download,layout:false
  end

  def download_pc_page
    redirect '/' unless @current_user && @current_user.isVerified
    erb :download_pc,layout:false
  end

  def about_us_page
    @this_title = "关于喜马拉雅 喜马拉雅-听我想听"
    erb :about_us
  end

  def contact_us_page
    @this_title = "联系我们 喜马拉雅-听我想听"
    erb :contact_us
  end

  def official_news_page
    @this_title = "官方新闻 喜马拉雅-听我想听"

    @page = (tmp=params[:page].to_i)>0 ? tmp :1
    @per_page = 20

    @news_count = News.count
    @news_list = News.order('time_at desc').offset((@page-1)*@per_page).limit(@per_page)
    erb :official_news
  end

  def join_us_page
    @this_title = "加入我们 喜马拉雅-听我想听"
    erb :join_us
  end

  def download1_page
    erb :download1,layout:false
  end

  def dload_page
    erb :dload,layout:false
  end

  def silian_sound
    now = Time.new
    today = Time.new(now.year, now.mon, now.day)
    deads = DeadTrack.where('created_at >= ? and created_at < ?', today, today + 86400)
    deads.map{|dead| "#{request.protocol}#{request.host_with_port}/#{dead.uid}/sounsilian_soundd/#{dead.track_id}" }.join("\n")
  end

  def silian_album
    now = Time.new
    today = Time.new(now.year, now.mon, now.day)
    deads = DeadAlbum.where('created_at >= ? and created_at < ?', today, today + 86400)
    deads.map{|dead| "#{request.protocol}#{request.host_with_port}/#{dead.uid}/album/#{dead.album_id}" }.join("\n")
  end

  def silian_user
    now = Time.new
    today = Time.new(now.year, now.mon, now.day)
    deads = DeadUser.where('created_at >= ? and created_at < ?', today, today + 86400)
    deads.map{|dead| "#{request.protocol}#{request.host_with_port}/#{dead.uid}" }.join("\n")
  end

  def cache_file
    #File.read("#{Sinarey.root}/app/views/welcome/cache_page.erb")
    IO.read("#{Sinarey.root}/app/views/welcome/cache_page.erb")
  end

  def cache_nil
    erb :cache_page,layout:false
  end

  def cache_redis
    CMSREDIS.get(:home_sinarey_cache)
  end

  def set_redis_cache
    CMSREDIS.set(:home_sinarey_cache,File.read("#{Sinarey.root}/app/views/welcome/cache_page.erb"))
  end

  def del_redis_cache
    CMSREDIS.del(:home_sinarey_cache)
  end

end