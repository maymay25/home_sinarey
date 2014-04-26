
class MainController < ApplicationController

  set :views, ['main','application']

  #新版未登录首页
  def index

    set_no_cache_header
    register_page('main','index')

    halt erb(:index2,layout:false) unless @current_uid

    erb :index
  end

  def global_counts_json
    set_no_cache_header
    tracks, users = $counter_client.getByNames([Settings.counter.tracks, Settings.counter.vusers], 0)
    render_json({tracks: tracks, users: users})
  end

  def silian_sound
    now = Time.new
    today = Time.new(now.year, now.mon, now.day)
    deads = DeadTrack.where('created_at >= ? and created_at < ?', today, today + 86400)
    deads.map{|dead| "#{request.protocol}#{request.host_with_port}/#{dead.uid}/sound/#{dead.track_id}" }.join("\n")
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

end
