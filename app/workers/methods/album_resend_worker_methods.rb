module AlbumResendWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def album_resend(album_ids,uid)
    album_ids.each do |album_id|
      ts = TrackSet.stn(album_id).where(id: album_id).first
      next if ts.nil?
      album_copy = Album.create(uid: uid,
        nickname: ts.nickname,
        avatar_path: ts.avatar_path,
        is_v: ts.is_v,
        is_public: ts.is_public,
        is_publish: ts.is_publish,
        user_source: ts.user_source,
        category_id: ts.category_id,
        tags: ts.tags,
        title: ts.title,
        intro: ts.intro,
        cover_path: ts.cover_path,
        music_category: ts.music_category,
        is_crawler: ts.is_crawler,
        op_type: 2,
        rich_intro: ts.rich_intro,
        short_intro:ts.short_intro,
        is_deleted: ts.is_deleted,
        source_url: ts.source_url,
        is_records_desc: ts.is_records_desc,
        last_uptrack_at: ts.last_uptrack_at,
        last_uptrack_id: ts.last_uptrack_id,
        last_uptrack_title: ts.last_uptrack_title,
        last_uptrack_cover_path: ts.last_uptrack_cover_path,
        status: ts.status,
        dig_status: ts.dig_status,
        human_category_id: ts.human_category_id,
        extra_tags: ts.extra_tags,
        is_finished: ts.is_finished
      )

      $counter_client.incr(Settings.counter.user.albums, album_copy.uid, 1)

      new_record_ids = []

      TrackRecord.stn(ts.uid).where(uid: ts.uid, album_id: ts.id).each do |record|
        record_copy = TrackRecord.create(op_type: 2,
          track_id: record.track_id,
          track_uid: record.track_uid,
          track_upload_source: record.upload_source,
          uid: album_copy.uid,
          nickname: album_copy.nickname,
          avatar_path: album_copy.avatar_path,
          is_public: record.is_public,
          is_publish: record.is_publish,
          is_v: album_copy.is_v,
          user_source: record.user_source,
          category_id: record.category_id,
          tags: record.tags,
          title: record.title,
          intro: record.intro,
          short_intro: record.short_intro,
          rich_intro: record.rich_intro,
          cover_path: record.cover_path,
          duration: record.duration,
          download_path: record.download_path,
          play_path: record.play_path,
          play_path_32: record.play_path_32,
          play_path_64: record.play_path_64,
          play_path_128: record.play_path_128,
          singer: record.singer,
          singer_category: record.singer_category,
          author: record.author,
          composer: record.composer,
          arrangement: record.arrangement,
          post_production: record.post_production,
          lyric_path: record.lyric_path,
          language: record.language,
          resinger: record.resinger,
          announcer: record.announcer,
          allow_download: record.allow_download,
          allow_comment: record.allow_comment,
          is_crawler: record.is_crawler,
          upload_source: record.upload_source,
          album_id: album_copy.id,
          album_title: album_copy.title,
          album_cover_path: album_copy.cover_path,
          transcode_state: record.transcode_state,
          music_category: record.music_category,
          order_num: record.order_num,
          is_pick: record.is_pick,
          dig_status: record.dig_status,
          approved_at: record.approved_at,
          is_deleted: record.is_deleted,
          mp3size: record.mp3size,
          mp3size_32: record.mp3size_32,
          mp3size_64: record.mp3size_64,
          waveform: record.waveform,
          upload_id: record.upload_id,
          source_url: record.source_url,
          status: record.status,
          explore_height: record.explore_height,
          download_size: record.download_size
        )

        $counter_client.incr(Settings.counter.album.tracks, album_copy.id, 1)

        new_record_ids << record_copy.id
      end

      album_copy.tracks_order = new_record_ids.join(',')
      album_copy.save
    end # album_ids.each do |album_id|
    logger.info "#{Time.now} resend #{album_ids.inspect} to #{uid}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/album_recend#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end