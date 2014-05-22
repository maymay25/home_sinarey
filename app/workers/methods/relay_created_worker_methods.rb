module RelayCreatedWorkerMethods

  include ApnDispatchHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def relay_created(tid,content,uid,record_id,sharing_to)

    content = content.to_s.strip
    current_user = $profile_client.queryUserBasicInfo(uid)
    short_content = cut_str(content,60,'..')
    track = Track.stn(tid).where(id: tid).first

    # 同时生成一条对原声音的评论 （如果有输入内容)
    if content.present?
      # 评论
      comment = Comment.create(uid: uid,
        track_id: track.id,
        track_uid: track.uid,
        track_nickname: track.nickname,
        track_title: track.title,
        track_duration: track.duration,
        track_created_at: track.created_at,
        track_avatar_path: track.avatar_path,
        second: nil,
        parent_id: nil,
        content: content,
        nickname: current_user.nickname,
        avatar_path: current_user.logoPic,
        play_path: track.play_path,
        play_path_32: track.play_path_32,
        play_path_64: track.play_path_64,
        play_path_128: track.play_path_128,
        user_source: track.user_source,
        cover_path: track.cover_path
      )

      relay_track_record = TrackRecord.stn(uid).where(id: record_id).first
      relay_track_record.update_attributes(comment_content:short_content,comment_id:comment.id) if relay_track_record
      
      $counter_client.incr(Settings.counter.track.comments, track.id, 1)

      # 发件箱 我评论的 
      Outbox.create(uid: uid,
        nickname: current_user.nickname,
        to_uid: track.uid,
        to_nickname: track.nickname,
        message_type: 2,
        content: content,
        track_id: track.id, 
        track_title: track.title, 
        track_cover_path: track.cover_path, 
        track_uid: track.uid, 
        track_nickname: track.nickname, 
        comment_id: comment.id, 
        second: nil,
        extra_json: { 
          track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
          track_uid: track.uid, track_nickname: track.nickname, comment_id: comment.id, second: nil
        }.to_json,
        avatar_path: current_user.logoPic,
        to_avatar_path: track.avatar_path
      )

      # 圈到的
      refer_names = select_names(content)
      if refer_names.size > 0
        quan_ignores = [current_user.nickname]
        refer_users_dj = []
        refer_users_push_dj = []
        refer_names.uniq.each do |refer_name|
          next if quan_ignores.include?(refer_name)
          refer_users = $profile_client.getProfileByNickname(refer_name)
          next if refer_users.empty?
          u = refer_users.first

          #黑名单
          next if BlackUser.where(uid:u.uid,black_uid:current_user.uid).first

          ps = PersonalSetting.where(uid: u.uid).first
          if ps
            ignored = case ps.allow_at_me_content
            when 2
              true if !current_user.isVerified and !Following.stn(u.uid).where(uid: u.uid, following_uid: current_user.uid).any? and !Follower.stn(u.uid).where(uid: current_user.uid, following_uid: u.uid).any?
            when 3
              true unless Following.stn(u.uid).where(uid: u.uid, following_uid: current_user.uid).any?
            when 4
              true
            else
              false
            end
          else
            ignored = false
          end

          next if ignored

          Inbox.create(uid: current_user.uid,
            nickname: current_user.nickname,
            to_uid: u.uid,
            to_nickname: u.nickname,
            message_type: 4,
            content: comment.content,
            track_id: track.id, 
            track_title: track.title, 
            track_cover_path: track.cover_path, 
            track_uid: track.uid, 
            track_nickname: track.nickname, 
            comment_id: comment.id, 
            second: comment.second,
            extra_json: { track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
                track_uid: track.uid, track_nickname: track.nickname, comment_id: comment.id, second: comment.second }.to_json,
            avatar_path: current_user.logoPic,
            to_avatar_path: u.middlePic
          )

          is_notice = ps ? ps.notice_quan : true

          refer_users_dj << u if is_notice
          refer_users_push_dj << u
        end # -- do |refer_name|
      end # -- if refer_names.size > 0

      if refer_users_dj and refer_users_dj.size > 0
        refer_users_dj.each do |u|
          $counter_client.incr(Settings.counter.user.new_quan, u.uid, 1)
        end
      end

      if refer_users_push_dj and refer_users_push_dj.size > 0
        refer_users_push_dj.each_index do |index|
          dispatch_comment(4, refer_users_push_dj[index], comment)
        end
      end
    end

    track_user_ps = PersonalSetting.where(uid: track.uid).first
    if track_user_ps
      ignored = case track_user_ps.allow_at_me_content
      when 2
        true if !current_user.isVerified and !Following.stn(track.uid).where(uid: track.uid, following_uid: current_user.uid).any? and !Follower.stn(track.uid).where(uid: current_user.uid, following_uid: track.uid).any?
      when 3
        true unless Following.stn(track.uid).where(uid: track.uid, following_uid: current_user.uid).any?
      when 4
        true
      else
        false
      end
    else
      ignored = false
    end

    unless ignored
      # 生成一条@原作者的转发消息
      Inbox.create(uid: uid,
          nickname: current_user.nickname,
          to_uid: track.uid,
          to_nickname: track.nickname,
          message_type: 8,
        content: content,
        track_id: track.id, 
        track_title: track.title,
        track_cover_path: track.cover_path, 
        track_uid: track.uid, 
        track_nickname: track.nickname, 
        comment_id: comment ? comment.id : nil,
        extra_json: {
          track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
          track_uid: track.uid, track_nickname: track.nickname, comment_id: comment ? comment.id : nil 
        }.to_json,
        avatar_path: current_user.logoPic,
        to_avatar_path: track.avatar_path
      )
      $counter_client.incr(Settings.counter.user.new_quan, track.uid, 1)
    end

    # 更新用户最新声音
    latest = LatestTrack.where(uid: uid).first
    hash = {
      album_id: track.album_id,
      album_title: track.album_title,
      nickname: current_user.nickname,
      is_resend: true,
      is_v: current_user.isVerified,
      track_cover_path: track.cover_path,
      track_created_at: track.created_at,
      track_id: track.id,
      track_title: track.title,
      uid: uid,
      waveform: track.waveform,
      upload_id: track.upload_id
    }
    if latest
      latest.update_attributes(hash)
    else
      LatestTrack.create(hash)
    end

    if track_user_ps.nil? or track_user_ps.allow_at_me_content
      dispatch_relay(track.uid, track.id, track.title, content, uid, current_user.nickname) 
    end

    #用户声音数 +1 
    $counter_client.incr(Settings.counter.user.tracks, uid, 1)

    if sharing_to
      if content.present?
        share_content = "“#{cut_str(content, 100, '...')}” 我转发了《#{track.title}》"
      else
        share_content = "我转发了《#{track.title}》"  
      end
      message = {syncType: 'relay', cleintType:'web', uid: uid.to_s, thirdpartyNames: sharing_to, title: track.title, summary: track.intro, comment: share_content, url: "#{Settings.home_root}/#{track.uid}/sound/#{track.id}", images: file_url(track.cover_path)}
      $rabbitmq_channel.queue('thirdparty.feed.queue', durable: true).publish(Oj.dump(message, mode: :compat), content_type: 'text/plain')
    end
    logger.info "#{Time.now} #{uid} #{tid} #{sharing_to}\n"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e 
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/relay_created#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end
