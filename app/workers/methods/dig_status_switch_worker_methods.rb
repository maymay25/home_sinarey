module DigStatusSwitchWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def dig_status_switch(uids,dig_status,is_v,is_crawler)

    attrs = {}
    attrs[:dig_status] = dig_status unless dig_status.nil?
    attrs[:is_v] = is_v unless is_v.nil?
    attrs[:is_crawler] = is_crawler unless is_crawler.nil?

    uids ||= []
    uids.each do |uid|
      TrackRecord.stn(uid).where(uid: uid, op_type: 1).each do |record|
        record.update_attributes(attrs)
        track = Track.stn(record.track_id).where(id: record.track_id).first
        if track
          track.update_attributes(attrs)
          $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash), content_type: 'text/plain', persistent: true)
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
          end
          track0.updated_at = track.updated_at
          track0.update_attributes(trackhash)
        end
      end

      Album.stn(uid).where(uid: uid).each do |album|
        album.update_attributes(attrs)
        $rabbitmq_channel.fanout(Settings.topic.album.updated, durable: true).publish(Yajl::Encoder.encode(album.to_topic_hash), content_type: 'text/plain', persistent: true)
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
        end
        album0.updated_at = album.updated_at
        album0.update_attributes(albumhash)
      end
    end

    logger.info "#{Time.now} #{uids.inspect} #{dig_status} #{is_v} #{is_crawler}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/dig_status_switch#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end
