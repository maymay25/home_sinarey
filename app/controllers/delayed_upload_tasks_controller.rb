class DelayedUploadTasksController < ApplicationController

  def dispatch(action,params_options={})
    params_options.each {|k,v| params[k] = v }
    super(:delayed_upload_tasks,action)
    method(action).call
  end

  def get_my_publish_tracks_and_album
    
    halt_400 unless @current_uid

    if params[:delayed_track_id]
      delayed_track =  DelayedTrack.find(params[:delayed_track_id])
      delayed_track.destroy
    end

    if params[:delayed_album_id]
      delayed_album = DelayedAlbum.find(params[:delayed_album_id])
      delayed_tracks = DelayedTrack.where(:delayed_album_id => delayed_album.id)
      delayed_album.destroy
      delayed_tracks.each do |delayed_track|
        delayed_track.destroy
      end
    end

    render_json({res: true, msg: print_message(:success)})
  end

  def get_delayed_track_json

    delayed_track = DelayedTrack.find(params[:id])
    
    halt render_json({}) if delayed_track.nil?

    hash = {
      id: delayed_track.id,
      uid: @current_uid,
      album_cover_path: delayed_track.album_cover_path,
      category_id: delayed_track.category_id,
      cover_path: delayed_track.cover_path,
      delayed_album_id: delayed_track.delayed_album_id,
      download_path: delayed_track.download_path,
      duration: delayed_track.duration,
      human_category_id: delayed_track.human_category_id,
      intro: delayed_track.intro,
      is_v: delayed_track.is_v,
      mp3size: delayed_track.mp3size,
      mp3size_32: delayed_track.mp3size_32,
      mp3size_64: delayed_track.mp3size_64,
      music_category: delayed_track.music_category,
      nickname: delayed_track.nickname,
      play_path: delayed_track.play_path,
      play_path_128: delayed_track.play_path_128,
      play_path_32: delayed_track.play_path_32,
      play_path_64: delayed_track.play_path_64,
      rich_intro: delayed_track.rich_intro,
      short_intro: delayed_track.short_intro,
      singer: delayed_track.singer,
      singer_category: delayed_track.singer_category,
      source_url:delayed_track.source_url,
      status:delayed_track.status,
      tags: delayed_track.tags,
      title: delayed_track.title,
      transcode_state: delayed_track.transcode_state,
      uid: delayed_track.uid,
      upload_id: delayed_track.upload_id,
      upload_source: delayed_track.upload_source,
      user_source: delayed_track.user_source,
      waveform: delayed_track.waveform
    }

    render_json(hash)
  end

  def publish_report_message
    type = params[:type].to_i
    success = params[:success].to_i
    uid = params[:uid].to_i

    publish_at = Time.at(params[:publish_at][0,10].to_i).strftime("%Y-%m-%d %H:%M")
    content = ""
    if success == 1
      if type == 1
        track_title = CGI::unescape(params[:track_title])
        content = "定于 #{publish_at} 发布的 #{track_title} 已经成功发布了！"
      elsif type == 2
        album_title = CGI::unescape(params[:album_title])
        unless params[:track_titles]
          content = "定于 #{publish_at} 发布的《#{album_title}》已经成功发布了！"
        else
          track_titles = CGI::unescape(params[:track_titles])
          content = "定于 #{publish_at} 发布的《#{album_title}》中的 #{track_titles} 等声音已经成功发布了！"
        end
        
      end
    elsif success == 0

      if type == 1
        delay_track_id = params[:delay_track_id]
        delay_track = DelayedTrack.find(delay_track_id)
        uid = delay_track.uid
        publish_at = Time.at(delay_track.publish_at.to_i).strftime("%Y-%m-%d %H:%M")
        content = "定于 #{publish_at} 发布的 #{delay_track.title} 发布失败！"
      elsif type == 2
        # delay_track_ids = params[:delay_track_ids]
        delay_album_id = params[:delay_album_id]
        delay_album = DelayedAlbum.find(delay_album_id)
        uid = delay_album.uid
        delay_tracks = DelayedTrack.where(:delayed_album_id => delay_album_id)

        delay_track_name = []
        delay_tracks.each do |delay_track|
          delay_track_name << delay_track.title
        end
        if delay_track_name.size == 1
          track_titles = delay_track_name[0]
        else
          track_titles = delay_track_name.join(",")
        end

        publish_at = Time.at(delay_album.publish_at.to_i).strftime("%Y-%m-%d %H:%M")
        content = "定于 #{publish_at}发布的 《#{delay_album.title}》 中的 #{track_titles} 等声音发布失败！"
      end
    end

    xima = $profile_client.queryUserBasicInfo(1)

    author = $profile_client.queryUserBasicInfo(uid)
    Inbox.create( uid: xima.uid,
          nickname: xima.nickname,
          avatar_path: xima.logoPic,
          to_uid: uid,
          to_nickname: author.nickname,
          to_avatar_path: author.logoPic,
          message_type: 5,
          content: content )

    $counter_client.incr(Settings.counter.user.new_notice, uid, 1)

    render json:{ret:0,msg:"ok"}
  end


end
