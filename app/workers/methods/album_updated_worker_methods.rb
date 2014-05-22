module AlbumUpdatedWorkerMethods

  include CoreHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def album_updated(album_id,is_new,user_agent,created_records_ids,updated_track_ids,moved_record_id_old_album_ids,destroyed_track_ids,no_feed_track_ids,share_opts,share_type)

    trackset = TrackSet.stn(album_id).where(id: album_id).first
    album = Album.stn(trackset.uid).where(id: trackset.id).first

    created_record_ids = created_record_ids || []
    passed_new_public_record_ids = []
    created_tracks = []
    no_feed_track_ids = no_feed_track_ids || []

    if created_record_ids.size > 0
      created_records = TrackRecord.stn(album.uid).where(uid: album.uid, album_id: album.id, id: created_record_ids).order('id')
      created_records.each do |record|

        if record.status == 1 && record.is_public && !record.is_deleted 
          passed_new_public_record_ids << record.id
          last_tr = record
        end
        
        if record.is_public && record.status == 1 && !record.is_deleted
          # 用户声音数+
          $counter_client.incr(Settings.counter.user.tracks, album.uid, 1)

          # 专辑声音数+
          $counter_client.incr(Settings.counter.album.tracks, album.id, 1)
        end

        if record.op_type == 1
          track = Track.stn(record.track_id).where(id: record.track_id).first
          if track.is_public
            if track.status == 1 && !track.is_deleted
              # 全站声音数+
              $counter_client.incr(Settings.counter.tracks, 0, 1)
              
              # 专辑播放数+
              plays = $counter_client.get(Settings.counter.track.plays, track.id)
              $counter_client.incr(Settings.counter.album.plays, album.id, plays) if plays > 0

              created_tracks << track
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
            end
          end

          # track origin
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
      end
    else
      created_records = []
    end
    
    # 更新 用户最新一张专辑信息
    if album.status == 1 && album.is_public && album.cover_path
      la = LatestAlbum.where(uid: album.uid).first
      hash = {
        album_cover_path: album.cover_path,
        album_created_at: album.created_at,
        album_id: album.id,
        album_title: album.title,
        nickname: album.nickname,
        uid: album.uid
      }
      if la
        la.update_attributes(hash)
      else
        LatestAlbum.create(hash)
      end
    end

    # 每个新创建的声音
    if created_tracks.size > 0
      created_tracks.each do |track|

        if track.tags
          track.tags.split(',').each do |tag|
            next if tag.empty?
            $counter_client.incr(Settings.counter.tag.tracks, tag, 1)
          end
        end

        CoreAsync::TrackOnWorker.perform_async(:track_on, track.id, true, nil, nil)
        $rabbitmq_channel.fanout(Settings.topic.track.created, durable: true).publish(Oj.dump(track.to_topic_hash.merge(user_agent: user_agent, is_feed: !no_feed_track_ids.include?(track.id)), mode: :compat), content_type: 'text/plain', persistent: true) if track.play_path_64
        logger.info "#{Time.now} #{album.uid} #{Settings.topic.track.created} #{track.id} #{track.play_path_64}"
      end

      # 分享
      if share_opts
        sharing_to, share_content = share_opts
        if sharing_to and share_content
          # 用户自定义
          share_content = share_content.gsub("《标题》","《#{album.title}》").gsub("{{count}}","#{created_tracks.size}")
        else
          if created_tracks.size == 1 and share_type == "sound"
            shared_track = created_tracks.first
            if shared_track.is_public
              m_user = MUser.where(uid: shared_track.uid).first
              if m_user
                # 后台用户默认
                if shared_track.intro and !shared_track.intro.strip.empty?
                  share_content = cut_str(shared_track.intro, 80, '...')
                else
                  share_content = shared_track.title
                end
              else
                # 普通用户默认
                share_content = "我刚刚用#喜马拉雅#发布了好声音《#{shared_track.title}》，好声音要和朋友一起听！觉得不错就评论转发吧 ：）"
              end
            end
          else
            m_user = MUser.where(uid: album.uid).first
            if m_user
              # 后台用户默认
              if album.intro and !album.intro.strip.empty?
                share_content = cut_str(album.intro, 80, '...')
              else
                share_content = album.title
              end
            else
              # 普通用户默认
              share_content = "我的专辑又更新啦！刚刚添加了#{created_tracks.size}个声音到专辑《#{album.title}》，喜欢的亲们赶紧去听听吧！"
            end
          end
        end

        message = { syncType: 'album', cleintType:'web', uid: album.uid.to_s, thirdpartyNames: sharing_to, title: album.title, summary: '', comment: share_content, url: "#{Settings.home_root}/#{album.uid}/album/#{album.id}", images: file_url(album.cover_path) }
        $rabbitmq_channel.queue('thirdparty.feed.queue', durable: true).publish(Oj.dump(message, mode: :compat), content_type: 'text/plain')
        #logger.info(params['share'].inspect)
      end
    end

    last_tr ||= TrackRecord.stn(album.uid).where(uid:album.uid,album_id:album.id,status:1,is_public:1,is_deleted:0).last

    if last_tr
      #logger.info("#{Time.now} last_tr.track_id #{last_tr.track_id} album.last_uptrack_id #{album.last_uptrack_id}")
      if last_tr.track_id != album.last_uptrack_id
        # 更新专辑的最后更新声音
        album.update_attributes(last_uptrack_id: last_tr.track_id, last_uptrack_at: last_tr.created_at, last_uptrack_title: last_tr.title, last_uptrack_cover_path: last_tr.cover_path)
        $rabbitmq_channel.queue('last_uptrack.rb', durable: true).publish(Hessian2.write({ album_id: album.id, last_uptrack_at: last_tr.created_at }), content_type: 'text/plain')
        logger.info("#{Time.now} publish last_uptrack.rb #{last_tr.created_at}")
      end
      # 更新 用户最新发的声音
      user = $profile_client.queryUserBasicInfo(last_tr.uid)
      latest = LatestTrack.where(uid: last_tr.uid).first
      hash = {
        album_id: last_tr.album_id,
        album_title: last_tr.album_title,
        is_resend: last_tr.op_type == 2,
        is_v: user.isVerified,
        nickname: last_tr.nickname,
        track_cover_path: last_tr.cover_path,
        track_created_at: last_tr.created_at,
        track_id: last_tr.track_id,
        track_title: last_tr.title,
        
        uid: last_tr.uid,
        waveform: last_tr.waveform,
        upload_id: last_tr.upload_id
      }
      if latest
        latest.update_attributes(hash)
      else
        LatestTrack.create(hash)
      end
    elsif album.last_uptrack_id # last_tr不存在，清掉专辑的最后更新声音信息
      album.update_attributes(last_uptrack_id: nil, last_uptrack_at: nil, last_uptrack_title: nil, last_uptrack_cover_path: nil)
      $rabbitmq_channel.queue('last_uptrack.rb', durable: true).publish(Hessian2.write({ album_id: album.id, last_uptrack_at: nil }), content_type: 'text/plain')
      logger.info("#{Time.now} publish last_uptrack.rb")
    end

    # 删除的声音
    if destroyed_track_ids
      destroyed_track_ids.each do |id|
        track = Track.stn(id).where(id: id, uid: album.uid).first
        next unless track

        if track.is_public && track.status == 1
          # 专辑声音数-
          $counter_client.decr(Settings.counter.album.tracks, album.id, 1)
          # 用户声音数-
          $counter_client.decr(Settings.counter.user.tracks, album.uid, 1)
          # 全站声音数-
          $counter_client.decr(Settings.counter.tracks, 0, 1)
          # 专辑播放数-
          plays = $counter_client.get(Settings.counter.track.plays, track.id)
          $counter_client.decr(Settings.counter.album.plays, track.album_id, plays) if plays > 0

          CoreAsync::TrackOffWorker.perform_async(:track_off,track.id,true)
          $rabbitmq_channel.fanout(Settings.topic.track.destroyed, durable: true).publish(Oj.dump(track.to_topic_hash.merge(updated_at: Time.now, is_feed: true), mode: :compat), content_type: 'text/plain', persistent: true)
          logger.info "#{Time.now} #{album.uid} topic.track.destroyed #{track.id}"

          HumanRecommendCategoryTrack.where(track_id: track.id).each{|r| r.destroy }
          HumanRecommendTagTrack.where(track_id: track.id).each{|r| r.destroy }
          HumanRecommendCategoryTagTrack.where(track_id: track.id).each{|r| r.destroy }
          DeadTrack.create(track_id: track.id, uid: track.uid)
          
        end
      end
    end

    # 被更新过的原有的声音
    if updated_track_ids
      updated_track_ids.each do |id|
        track = Track.stn(id).where(id: id, uid: album.uid).first
        if track
          $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Oj.dump(track.to_topic_hash, mode: :compat), content_type: 'text/plain', persistent: true)
          logger.info "#{Time.now} #{album.uid} #{Settings.topic.track.updated} #{track.id}"
        end
      end
    end

    # 移动的声音
    if moved_record_id_old_album_ids
      moved_record_id_old_album_ids.each do |record_id, old_album_id|
        logger.info "move record #{record_id} from album #{old_album_id ? old_album_id : 'nil'}"
        record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id).first
        if record && track = Track.stn(record.track_id).where(id: record.track_id).first
          plays = $counter_client.get(Settings.counter.track.plays, track.id)

          # 专辑声音数+
          $counter_client.incr(Settings.counter.album.tracks, album.id, 1) if track.status == 1 && track.is_public

          # 专辑播放数+
          if record.op_type == 1 && plays > 0
            $counter_client.incr(Settings.counter.album.plays, album.id, plays)
            #logger.info "#{Time.now} #{album.title} #{Settings.counter.album.plays} + #{plays}"
          end

          $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Oj.dump(track.to_topic_hash, mode: :compat), content_type: 'text/plain', persistent: true)

          # 老专辑
          if old_album_id
            old = Album.stn(album.uid).where(id: old_album_id, uid: album.uid).first
            if old
              old.tracks_order = old.tracks_order.split(',').delete_if{ |id| id == record.id }.join(",") if old.tracks_order
              last = TrackRecord.stn(old.uid).where(uid: old.uid, album_id: old.id, is_deleted: false, status: 1, is_public: true).order('created_at desc').first
              if last
                if last.track_id != old.last_uptrack_id
                  old.last_uptrack_at = last.created_at
                  old.last_uptrack_id = last.track_id
                  old.last_uptrack_title = last.title
                  old.last_uptrack_cover_path = last.cover_path
                end
              else
                old.last_uptrack_at = nil
                old.last_uptrack_id = nil
                old.last_uptrack_title = nil
                old.last_uptrack_cover_path = nil
              end

              old.save

              $rabbitmq_channel.fanout(Settings.topic.album.updated, durable: true).publish(Oj.dump(old.to_topic_hash, mode: :compat), content_type: 'text/plain', persistent: true)
              logger.info "#{Time.now} #{album.uid} #{Settings.topic.album.updated} old #{old.id}"

              # 老专辑声音数-
              $counter_client.decr(Settings.counter.album.tracks, old.id, 1) if track.status == 1 && track.is_public
              
              # 专辑播放数-
              if record.op_type == 1 && plays > 0
                $counter_client.decr(Settings.counter.album.plays, old.id, plays)
                logger.info "#{Time.now} #{old.title} #{Settings.counter.album.plays} - #{plays}"
              end
             
            end
          end # if old_album_id
        end # if record and track
      end
    end

    # album的topic需要在更新完last_uptrack_xxx之后发
    if is_new # 新建专辑的场合
      if album.status == 1
        # 用户的专辑数+ 
        $counter_client.incr(Settings.counter.user.albums, album.uid, 1)

        $rabbitmq_channel.fanout(Settings.topic.album.created, durable: true).publish(Oj.dump(album.to_topic_hash.merge(user_agent: user_agent, is_feed: true), mode: :compat), content_type: 'text/plain', persistent: true)
        logger.info "#{Time.now} #{album.uid} #{Settings.topic.album.created} #{album.id}"

        if album.tags
          album.tags.split(',').each do |tag|
            next if tag.empty?
            # 标签的专辑数+
            $counter_client.incr(Settings.counter.tag.albums, tag, 1)

            # 常用标签
            user_tag = UserTag.stn(album.uid).where(tag: tag).first
            if user_tag
              user_tag.update_attribute(:num, user_tag.num + 1)
            else
              UserTag.create(uid: album.uid, tag: tag, num: 1)
            end
          end
        end
      elsif album.status == 0
        uag = UidApproveGroup.where(uid: album.uid).first

        ApprovingAlbum.create(cover_path: album.cover_path,
          album_id: album.id,
          title: album.title,
          approve_group_id: uag ? uag.approve_group_id : nil,
          category_id: album.category_id,
          intro: album.intro,
          is_deleted: album.is_deleted,
          is_public: album.is_public,
          nickname: album.nickname,
          status: album.status,
          album_created_at: album.created_at,
          uid: album.uid,
          user_source: album.user_source,
          tags: album.tags
        )
      end
    else # 更新专辑
      $rabbitmq_channel.fanout(Settings.topic.album.updated, durable: true).publish(Oj.dump(album.to_topic_hash.merge(has_new_track: passed_new_public_record_ids.size > 0), mode: :compat), content_type: 'text/plain', persistent: true)
      logger.info "#{Time.now} #{album.uid} #{Settings.topic.album.updated} #{album.id}"
    end

    # album origin
    hash = album.attributes
    hash.delete('id')
    hash.delete('created_at')
    hash.delete('updated_at')
    album_origin = AlbumOrigin.where(id: album.id).first
    if album_origin.nil?
      album_origin = AlbumOrigin.new
      album_origin.id = album.id
      album_origin.created_at = album.created_at
    end
    album_origin.updated_at = album.updated_at
    album_origin.update_attributes(hash)
    
    logger.info "#{Time.now} #{album.uid} #{album.title} #{created_record_ids.inspect}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/album_updated#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end


end