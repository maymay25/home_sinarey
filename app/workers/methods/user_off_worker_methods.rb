module UserOffWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def user_off(uid,del_albums_tracks,del_comments)
 
    HumanRecommendCategoryTagUser.where(uid: uid).each{|r| r.destroy}
    HumanRecommendCategoryUser.where(uid: uid).each{|r| r.destroy}
    HumanRecommendTagUser.where(uid: uid).each{|r| r.destroy}

    if del_albums_tracks
      Album.stn(uid).where(uid: uid).each do |album|
        old_status = album.status
        album.update_attributes(is_publish: false, status: 2, dig_status: 2)
        $rabbitmq_channel.fanout(Settings.topic.album.destroyed, durable: true).publish(Yajl::Encoder.encode(album.to_topic_hash.merge(is_feed: true)), content_type: 'text/plain', persistent: true)

        if old_status != 2
          $counter_client.decr(Settings.counter.user.albums, album.uid, 1)

          HumanRecommendAlbum.where(album_id: album.id).each{|r| r.destroy }
          HumanRecommendCategoryAlbum.where(album_id: album.id).each{|r| r.destroy }
          HumanRecommendTagAlbum.where(album_id: album.id).each{|r| r.destroy }
          HumanRecommendCategoryTagAlbum.where(album_id: album.id).each{|r| r.destroy }

          unless DeadAlbum.where(album_id: album.id).any?
            DeadAlbum.create(album_id: album.id, uid: album.uid)
          end

          # AppAlbum.where(album_id: album.id).each{|r| r.destroy}
        end

        # album origin
        albumhash = album.attributes
        albumhash.delete('id')
        albumhash.delete('created_at')
        albumhash.delete('updated_at')
        album0 = AlbumOrigin.where(id: album.id).first
        unless album0
          album0 = AlbumOrigin.new
          album0.id = album.id
          album0.created_at = album.created_at
          album0.updated_at = album.updated_at
        end
        album0.update_attributes(albumhash)
      end

      # 下架声音
      destroyed_tracks = []
      records = TrackRecord.stn(uid).where(uid: uid)

      ActiveRecord::Base.transaction do
        records.each do |r|
          # old_record_is_publish = r.is_publish
          r.update_attributes(is_publish: false, status: 2, dig_status: 2)

          if r.op_type == 1
            track = Track.stn(r.track_id).where(id: r.track_id, uid: r.uid).first
            if track
              old_status = track.status
              track.update_attributes(is_publish: false, status: 2, dig_status: 2)
              CoreAsync::TrackOffWorker.perform_async(:track_off,track.id,false)
              $rabbitmq_channel.fanout(Settings.topic.track.destroyed, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(updated_at: Time.now, is_feed: true)), content_type: 'text/plain', persistent: true)
              destroyed_tracks << track if old_status != 2
            end
          end
        end
      end

      $counter_client.set(Settings.counter.user.tracks, uid, 0)
      
      if destroyed_tracks.size > 0
        destroyed_tracks.each do |track|
          if track.album_id
            $counter_client.decr(Settings.counter.album.tracks, track.album_id, 1)

            # 专辑播放数-
            plays = $counter_client.get(Settings.counter.track.plays, track.id)
            $counter_client.decr(Settings.counter.album.plays, track.album_id, plays) if plays > 0
          end
          
          HumanRecommendCategoryTrack.where(track_id: track.id).each{|r| r.destroy }
          HumanRecommendTagTrack.where(track_id: track.id).each{|r| r.destroy }
          HumanRecommendCategoryTagTrack.where(track_id: track.id).each{|r| r.destroy }

          unless DeadTrack.where(track_id: track.id).any?
            DeadTrack.create(track_id: track.id, uid: track.uid)
          end

          # track origin
          trackhash = track.attributes
          trackhash.delete('id')
          trackhash.delete('created_at')
          trackhash.delete('updated_at')
          track0 = TrackOrigin.where(id: track.id).first
          unless track0
            track0 = TrackOrigin.new
            track0.id = track.id
            track0.created_at = track.created_at
            track0.updated_at = track.updated_at
          end
          track0.update_attributes(trackhash)
        end
      end
    end

    if del_comments
      comments_origin = CommentOrigin.where(uid: uid)
      comments_origin.each do |origin|
        comment = Comment.stn(origin.track_id).where(id: origin.id).first
        if comment
          if comment.destroy

            $counter_client.decr(Settings.counter.track.comments, origin.track_id, 1)
            origin.destroy

            $rabbitmq_channel.fanout(Settings.topic.comment.destroyed, durable: true).publish(Yajl::Encoder.encode({
              id: comment.id,
              uid: comment.uid,
              track_id: comment.track_id,
              updated_at: Time.now,
              created_at: comment.created_at
            }), content_type: 'text/plain', persistent: true)

          else
            logger.info "#{Time.now} destroy #{comment.id} failed"
          end
        end
      end          
    end

    logger.info "#{Time.now} off #{uid} del_albums_tracks #{del_albums_tracks} del_comments #{del_comments}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/user_off#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end