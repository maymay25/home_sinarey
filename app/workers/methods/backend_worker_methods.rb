module BackendWorkerMethods

  include CoreHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def update_track_pic_category(uid,album_id,update_pic,cover_path,update_category,category_id)

    if update_pic and update_category
      track_records = TrackRecord.stn(uid).where(uid: uid, album_id: album_id)
      track_records.each do |t|
        t.cover_path = cover_path 
        t.category_id = category_id
        t.save
        track = Track.stn(t.track_id).where(id: t.track_id).first
        track.cover_path = cover_path
        track.category_id = category_id
        track.save

        $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(cover_path: cover_path)), content_type: 'text/plain', persistent: true)
      end    
    elsif update_pic 
      track_records = TrackRecord.stn(uid).where(uid: uid, album_id: album_id)
      track_records.each do |t|
        t.cover_path = cover_path
        t.save
        track = Track.stn(t.track_id).where(id: t.track_id).first
        track.cover_path = cover_path
        track.save

        $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(cover_path: cover_path)), content_type: 'text/plain', persistent: true)
      end
    elsif update_category
      track_records = TrackRecord.stn(uid).where(uid: uid, album_id: album_id)
      track_records.each do |t|
        t.category_id = category_id
        t.save
        track = Track.stn(t.track_id).where(id: t.track_id).first
        track.category_id = category_id
        track.save

        $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash), content_type: 'text/plain', persistent: true)
      end
    end
    logger.info "update_track_pic_category uid:#{uid}, update album_id:#{album_id}, uppic:#{update_pic}, upcat:#{update_category}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/backend#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end