module AlbumOffWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  # off_type 1: 连同声音删除 2: 不删声音 3: 连同声音下架
  def album_off(album_id,is_off,off_type)

      trackset = TrackSet.stn(album_id).where(id: album_id).first

      if trackset
        $counter_client.decr(Settings.counter.user.albums, trackset.uid, 1) if is_off

        HumanRecommendCategoryAlbum.where(album_id: trackset.id).each{|r| r.destroy }
        HumanRecommendTagAlbum.where(album_id: trackset.id).each{|r| r.destroy }
        HumanRecommendCategoryTagAlbum.where(album_id: trackset.id).each{|r| r.destroy }

        # AppAlbum.where(album_id: trackset.id).each{|r| r.destroy}

        if [1, 3].include?(off_type)
          destroyed_tracks = []

          if off_type == 1
            # 删除声音
            records = TrackRecord.stn(trackset.uid).where(uid: trackset.uid, album_id: trackset.id, is_deleted: false)
            records.each do |r|
              r.update_attribute(:is_deleted, true)

              if r.op_type == 1
                track = Track.stn(r.track_id).where(id: r.track_id, uid: trackset.uid, is_deleted: false).first
                if track
                  old_is_deleted = track.is_deleted
                  track.update_attribute(:is_deleted, true)

                  if !old_is_deleted && track.is_public && track.status == 1 
                    $counter_client.decr(Settings.counter.user.tracks, track.uid, 1)
                    $counter_client.decr(Settings.counter.tracks, 0, 1)

                    if track.album_id
                      $counter_client.decr(Settings.counter.album.tracks, track.album_id, 1)

                      # 专辑播放数-
                      plays = $counter_client.get(Settings.counter.track.plays, track.id)
                      $counter_client.decr(Settings.counter.album.plays, track.album_id, plays) if plays > 0
                    end

                    destroyed_tracks << track
                  end
                end
              end

              # track origin
              track0 = TrackOrigin.where(id: r.track_id).first
              track0.update_attribute('is_deleted', true) if track0
            end
          elsif params['op_type'] == 3
            # 下架声音
            records = TrackRecord.stn(trackset.uid).where(uid: trackset.uid, album_id: trackset.id, is_publish: true)
            records.each do |r|
              r.update_attributes(is_publish: false, status: 2)

              if r.op_type == 1
                track = Track.stn(r.track_id).where(id: r.track_id, uid: trackset.uid, is_publish: true).first
                if track
                  old_status = track.status
                  track.update_attributes(is_publish: false, status: 2)
                  destroyed_tracks << track

                  if !track.is_deleted && track.is_public && old_status == 1 
                    $counter_client.decr(Settings.counter.user.tracks, track.uid, 1)
                    $counter_client.decr(Settings.counter.tracks, 0, 1)

                    if track.album_id
                      $counter_client.decr(Settings.counter.album.tracks, track.album_id, 1)

                      # 专辑播放数-
                      plays = $counter_client.get(Settings.counter.track.plays, track.id)
                      $counter_client.decr(Settings.counter.album.plays, track.album_id, plays) if plays > 0
                    end
                  end
                end
              end

              # track origin
              track0 = TrackOrigin.where(id: r.track_id).first
              track0.update_attributes(is_publish: false, status: 2) if track0
            end
          end

         
          destroyed_tracks.each do |track|
            CoreAsync::TrackOffWorker.perform_async(:track_off,track.id,true)
            $rabbitmq_channel.fanout(Settings.topic.track.destroyed, durable: true).publish(Oj.dump(track.to_topic_hash.merge(is_feed: true, is_off: true), mode: :compat), content_type: 'text/plain', persistent: true)
          end
         
        elsif off_type == 2
          # 声音移出专辑
          updated_tracks = []
          records = TrackRecord.stn(trackset.uid).where(uid: trackset.uid, album_id: trackset.id)
          records.each do |r|
            r.update_attributes(album_id: nil, album_title: nil, album_cover_path: nil)

            if r.op_type == 1
              track = Track.stn(r.track_id).where(id: r.track_id).first
              if track
                track.update_attributes(album_id: nil, album_title: nil, album_cover_path: nil)
                updated_tracks << track
              end
            end
          end

          updated_tracks.each do |track|
            $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Oj.dump(track.to_topic_hash, mode: :compat), content_type: 'text/plain', persistent: true)
          end
        end

        # album origin
        hash = trackset.attributes
        hash.delete('id')
        hash.delete('created_at')
        hash.delete('updated_at')
        album_origin = AlbumOrigin.where(id: trackset.id).first
        if album_origin.nil?
          album_origin = AlbumOrigin.new
          album_origin.id = trackset.id
          album_origin.created_at = trackset.created_at
        end
        album_origin.updated_at = trackset.updated_at
        album_origin.update_attributes(hash)
        logger.info "#{Time.now} off #{trackset.id} #{trackset.title}"
      end

  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/album_off#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end