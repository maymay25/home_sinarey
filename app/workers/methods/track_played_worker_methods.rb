module TrackPlayedWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def track_played(track_id,uid)
    if uid and track_id
      now = Time.now
      oj = REDIS.get("listened#{uid}")
      if oj
        begin
          arr = Oj.load(oj)
          arr.delete_if{|listened_at, tid| tid == track_id }
          arr.pop if arr.size >= 50
        rescue ArgumentError => e
          arr = []
        end
      else
        arr = []
      end

      arr.insert(0, [ now, track_id ])
      REDIS.set("listened#{uid}", Oj.dump(arr))
    end
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  def incr_album_plays(track_id)
    tir = TrackInRecord.fetch(track_id)
    $counter_client.incr(Settings.counter.album.plays, tir.album_id, 1) if tir && tir.album_id
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/track_played#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end