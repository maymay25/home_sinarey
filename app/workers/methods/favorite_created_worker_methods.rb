module FavoriteCreatedWorkerMethods

  include CoreHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def favorite_created(fav_id,uid,upload_source,sharing_to,dotcom)
    fav = Favorite.stn(uid).where(id: fav_id).first
    return if fav.nil?
    user = $profile_client.queryUserBasicInfo(fav.uid)

    track = Track.stn(fav.track_id).where(id: fav.track_id).first

    # 喜欢通知
    return if fav.uid == track.uid
    fav_note = Inbox.stn(track.uid).where(to_uid: track.uid, message_type: 7, uid: fav.uid, content: track.id.to_s).first
    unless fav_note
      Inbox.create(uid: fav.uid,
        nickname: user.nickname,
        to_uid: track.uid,
        to_nickname: track.nickname,
        message_type: 7,
        content: track.id.to_s,
        avatar_path: user.logoPic,
        track_id: track.id, 
        track_title: track.title, 
        track_cover_path: track.cover_path, 
        track_uid: track.uid, 
        track_nickname: track.nickname, 
        avatar_path: user.logoPic,
        to_avatar_path: track.avatar_path,
        upload_source: upload_source
      )

      ps = PersonalSetting.where(uid: track.uid).first
      if ps.nil? or ps.notice_favorite
        $counter_client.incr(Settings.counter.user.new_like, track.uid, 1)
      end
    end

    # 喜欢加分享
    message = {syncType: 'favorite', cleintType:'web', uid: uid.to_s, thirdpartyNames:sharing_to, title: track.title, summary: track.intro, comment: "《#{track.title}》很喜欢！都来听听吧", url: "#{dotcom}/#{track.uid}/sound/#{track.id}", images: file_url(track.cover_path)}
    $rabbitmq_channel.queue('thirdparty.feed.queue', durable: true).publish(Yajl::Encoder.encode(message), content_type: 'text/plain')
    # 更新用户最新收藏声音
    lf = LatestFavorite.where(uid: fav.uid).first
    hash = {
      fav_created_at: fav.created_at,
      fav_id: fav.id,
      track_cover_path: track.cover_path,
      track_id: track.id,
      track_title: track.title,
      nickname: user.nickname,
      uid: user.uid
    }
    if lf
      lf.update_attributes(hash)
    else
      LatestFavorite.create(hash)
    end
    logger.info "#{Time.now} #{uid} #{fav_id} #{sharing_to}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/favorite_created#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end