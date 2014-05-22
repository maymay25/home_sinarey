module TrackOnWorkerMethods

  include ApnDispatchHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def track_on(track_id,is_new,share_opts,at_users)
    track = Track.stn(track_id).where(id: track_id).first
    user = $profile_client.queryUserBasicInfo(track.uid)

    common_works(track,user)

    update_track_origin(track)

    if is_new and track.status == 1 and track.is_public
      thirdparty_share(share_opts)
      notify_users(track,at_users)
    end
    
    logger.info "#{Time.now} #{track.uid} #{track.id} #{track.title} #{share_opts.inspect}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private


  def common_works(track,user)
    if track.is_public
      if track.status == 1
        $counter_client.incr(Settings.counter.user.tracks, track.uid, 1)

        $counter_client.incr(Settings.counter.tracks, 0, 1)

        if track.album_id
          $counter_client.incr(Settings.counter.album.tracks, track.album_id, 1)

          album = Album.stn(track.uid).where(id: track.album_id).first
          if track.id != album.last_uptrack_id
            album.update_attributes(last_uptrack_id: track.id, last_uptrack_at: track.created_at, last_uptrack_title: track.title, last_uptrack_cover_path: track.cover_path)
            $rabbitmq_channel.fanout(Settings.topic.album.updated, durable: true).publish(Yajl::Encoder.encode(album.to_topic_hash.merge(has_new_track: true)), content_type: 'text/plain', persistent: true)
          end
        end

        if track.tags
          track.tags.split(',').each do |tag|
            next if tag.empty?
            $counter_client.incr(Settings.counter.tag.tracks, tag, 1)
            # 常用标签
            user_tag = UserTag.stn(track.uid).where(tag: tag).first
            if user_tag
              user_tag.update_attribute(:num, user_tag.num + 1)
            else
              UserTag.create(uid: track.uid, tag: tag, num: 1)
            end
          end
        end

        # 更新用户最新声音
        latest = LatestTrack.where(uid: track.uid).first
        hash = {
          album_id: track.album_id,
          album_title: track.album_title,
          is_resend: false,
          is_v: user.isVerified,
          nickname: track.nickname,
          track_cover_path: track.cover_path,
          track_created_at: track.created_at,
          track_id: track.id,
          track_title: track.title,
          uid: track.uid,
          waveform: track.waveform,
          upload_id: track.upload_id
        }
        if latest
          latest.update_attributes(hash)
        else
          LatestTrack.create(hash)
        end
      elsif track.status == 0
        uag = UidApproveGroup.where(uid: track.uid).first

        ApprovingTrack.create(album_cover_path: track.album_cover_path,
          album_id: track.album_id,
          album_title: track.album_title,
          approve_group_id: uag ? uag.approve_group_id : nil,
          category_id: track.category_id,
          cover_path: track.cover_path,
          duration: track.duration,
          intro: track.intro,
          is_deleted: track.is_deleted,
          is_public: track.is_public,
          nickname: track.nickname,
          play_path: track.play_path,
          play_path: track.play_path_64,
          status: track.status,
          title: track.title,
          track_created_at: track.created_at,
          track_id: track.id,
          transcode_state: track.transcode_state,
          uid: track.uid,
          user_source: track.user_source,
          tags: track.tags
        )

        logger.info "#{Time.now} ApprovingTrack #{track.uid} #{track.id} #{track.title} created"
      end
    end
  end

  def update_track_origin(track)
    hash = track.attributes
    hash.delete('id')
    hash.delete('created_at')
    hash.delete('updated_at')
    track_origin = TrackOrigin.where(id: track.id).first
    if track_origin.nil?
      track_origin = TrackOrigin.new
      track_origin.id = track.id
      track_origin.created_at = track.created_at
    end
    track_origin.updated_at = track.updated_at
    track_origin.update_attributes(hash)
  end

  def thirdparty_share(share_opts)
      sharing_to, share_content = share_opts
      if sharing_to and share_content
        if share_content
          # 用户自定义
          share_content = share_content.gsub("《标题》","《#{track.title}》")
        else
          m_user = MUser.where(uid: track.uid).first
          if m_user
            # 后台用户
            if track.intro and !track.intro.empty?
              share_content = cut_str(track.intro, 80, '...')
            else
              share_content = track.title
            end
          else
            # 普通用户
            share_content = "我刚刚用#喜马拉雅#发布了好声音《#{track.title}》，好声音要和朋友一起听！觉得不错就评论转发吧 ：）"
          end
        end
        message = {syncType: 'track', cleintType:'web', uid: track.uid.to_s, thirdpartyNames: sharing_to, title: track.title, summary: track.intro, comment: share_content, url: "#{Settings.home_root}/#{track.uid}/sound/#{track.id}", images: file_url(track.cover_path)}
        $rabbitmq_channel.queue('thirdparty.feed.queue', durable: true).publish(Yajl::Encoder.encode(message), content_type: 'text/plain')
      end
  end

  def notify_users(track,at_users)
      if at_users
        refer_names = at_users.split(',')
        if refer_names.size > 0
          notice_users,push_users = [],[]
          refer_names.uniq.each do |refer_name|
            next if user.nickname == refer_name
            refer_users = $profile_client.getProfileByNickname(refer_name)
            next if refer_users.empty?
            u = refer_users.first

            # 黑名单
            next if BlackUser.where(uid:u.uid,black_uid:user.uid).first

            ps = PersonalSetting.where(uid: u.uid).first
            if ps
              ignored = case ps.allow_at_me_content
              when 2
                true if !user.isVerified and !Following.stn(u.uid).where(uid: u.uid, following_uid: user.uid).any? and !Follower.stn(u.uid).where(uid: user.uid, following_uid: u.uid).any?
              when 3
                true unless Following.stn(u.uid).where(uid: u.uid, following_uid: user.uid).any?
              when 4
                true
              else
                false
              end
            else
              ignored = false
            end

            next if ignored

            Inbox.create(uid: user.uid,
              nickname: user.nickname,
              to_uid: u.uid,
              to_nickname: u.nickname,
              message_type: 14,
              track_id: track.id, 
              track_title: track.title, 
              track_cover_path: track.cover_path,
              track_uid: track.uid, 
              track_nickname: track.nickname, 
              extra_json: { track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
              track_uid: track.uid, track_nickname: track.nickname }.to_json,
              avatar_path: user.logoPic,
              to_avatar_path: u.middlePic
            )

            is_notice = ps ? ps.notice_quan : true

            notice_users << u if is_notice
            push_users << u
          end
        end

        if notice_users and notice_users.size > 0
          notice_users.each do |u|
            $counter_client.incr(Settings.counter.user.new_quan, u.uid, 1)
          end
        end

        if push_users and push_users.size > 0
          push_users.each_index do |index|
            dispatch_upload_at(push_users[index], track)
          end
        end
      end
  end

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/track_on#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end