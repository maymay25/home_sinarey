module UserOnWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def user_on(uid)
    Album.stn(uid).where(uid: uid).each do |album|
      old_status = album.status
      album.update_attributes(is_publish: true, status: 1)
      $rabbitmq_channel.fanout(Settings.topic.album.updated, durable: true).publish(Yajl::Encoder.encode(album.to_topic_hash.merge(is_feed: true)), content_type: 'text/plain', persistent: true)

      if old_status == 2
        $counter_client.incr(Settings.counter.user.albums, album.uid, 1)
        
        dead_album = DeadAlbum.where(album_id: album.id).first
        if dead_album
          dead_album.destroy
        end
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

    # 解封声音
    pass_tracks = []
    records = TrackRecord.stn(uid).where(uid: uid)
    records.each do |r|
      r.update_attributes(is_publish: true, status: 1)

      if r.op_type == 1
        track = Track.stn(r.track_id).where(id: r.track_id, uid: r.uid).first
        if track
          old_status = track.status
          track.update_attributes(is_publish: true, status: 1)
          $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(updated_at: Time.now, is_feed: true)), content_type: 'text/plain', persistent: true)
          pass_tracks << track if old_status == 2 and !track.is_deleted
        end
      end
    end

    count = TrackRecord.stn(uid).where(uid: uid, status: 1, is_deleted: false, is_public: true).count
    $counter_client.set(Settings.counter.user.tracks, uid, count)
    
    if pass_tracks.size > 0
      
      pass_tracks.each do |track|
        if track.album_id
          $counter_client.incr(Settings.counter.album.tracks, track.album_id, 1)

          # 专辑播放数-
          plays = $counter_client.get(Settings.counter.track.plays, track.id)
          $counter_client.incr(Settings.counter.album.plays, track.album_id, plays) if plays > 0
        end
        
        dead_track =  DeadTrack.where(track_id: track.id).first
        dead_track.destroy if dead_track

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
    end # if pass_tracks.size > 0

    logger.info "#{Time.now} on #{uid}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/user_on#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end