module TrackOffWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def track_off(track_id,is_off)

    track = Track.stn(track_id).where(id: track_id).first

    if track
      if is_off
        $counter_client.decr(Settings.counter.user.tracks, track.uid, 1)
        $counter_client.decr(Settings.counter.tracks, 0, 1)

        if track.album_id
          $counter_client.decr(Settings.counter.album.tracks, track.album_id, 1)
          plays = $counter_client.get(Settings.counter.track.plays, track.id)
          $counter_client.decr(Settings.counter.album.plays, track.album_id, plays) if plays > 0
        end
      end

      HumanRecommendCategoryTrack.where(track_id: track.id).each{|r| r.destroy }
      HumanRecommendTagTrack.where(track_id: track.id).each{|r| r.destroy }
      HumanRecommendCategoryTagTrack.where(track_id: track.id).each{|r| r.destroy }
      DeadTrack.create(track_id: track.id, uid: track.uid)

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

      logger.info "#{Time.now} #{track.nickname} off #{track.id} #{track.title}"
    end
    
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/track_off#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end