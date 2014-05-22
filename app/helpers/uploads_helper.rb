module UploadsHelper
  include Inet

  #上传单条声音 [ 可选 添加到指定专辑 ]
  def upload_single_track(fileid,transcode_data,title,user_source,category_id,is_public,images,intro,rich_intro,tags,music_category,singer,singer_category,author,composer,arrangement,post_production,lyric,resinger,announcer,sharing_to,share_content,album)

    current_now = Time.now
    default_status = calculate_default_status(@current_user)

    track = Track.new
    track.upload_source = 2 # 网站
    track.is_crawler = false
    track.uid = @current_uid # 源发布者
    track.nickname = @current_user.nickname
    track.avatar_path = @current_user.logoPic
    track.is_v = @current_user.isVerified
    track.dig_status = calculate_dig_status(@current_user)
    track.human_category_id = @current_user.vCategoryId
    track.approved_at = current_now if default_status == 1
    track.title = title
    track.user_source = user_source
    track.category_id = category_id
    track.music_category = music_category
    track.tags = tags
    track.intro = intro
    track.short_intro = intro[0, 100]
    track.rich_intro = cut_intro(intro)
    track.singer = singer
    track.singer_category = singer_category
    track.author = author
    track.arrangement = arrangement
    track.post_production = post_production
    track.resinger = resinger
    track.announcer = announcer
    track.composer = composer
    track.is_publish = true
    track.is_public = is_public
    track.allow_download =  true
    track.allow_comment = true
    track.transcode_state = transcode_data['transcode_state']
    track.mp3size = transcode_data['paths']['origin_size']
    track.upload_id = transcode_data['upload_id']
    track.download_path = transcode_data['paths']['aacplus32']
    track.download_size = transcode_data['paths']['aacplus32_size']
    track.play_path = transcode_data['paths']['origin_path']
    track.play_path_32 = transcode_data['paths']['mp332']
    track.mp3size_32 = transcode_data['paths']['mp332_size']
    track.play_path_64 = transcode_data['paths']['mp364']
    track.mp3size_64 = transcode_data['paths']['mp364_size']
    track.duration = transcode_data['duration']
    track.waveform = transcode_data['waveform']

    if images.present?
      create_images,image_index = [],0
      images.each do |image|
        begin
        covers = Yajl::Parser.parse(image)
        if covers['status'] and covers['status']!=false and covers['data'] and cover=covers['data'].first and cover_track=cover['uploadTrack'] and paths = cover['processResult']
          create_images << [cover_track['id'].to_i, image_index+1, paths["origin"], paths["180n_height"]]
          if image_index.zero?
            track.cover_path = paths["origin"]
            track.explore_height = paths["180n_height"]
          end
          image_index += 1
        end
        rescue
          next
        end
      end
    end

    if album
      track.album_id = album.id
      track.album_title = album.title
      track.album_cover_path = album.cover_path
    end

    track.inet_aton_ip = inet_aton(get_client_ip)
    track.status = default_status
    track.save

    image_ids = []
    if create_images.present?
      create_images.each do |image_id,order_num,picture_path,explore_height|
        TrackPicture.create(track_id:track.id,uid:@current_uid,picture_path:picture_path,explore_height:explore_height,order_num:order_num)
        image_ids << image_id
      end
    end

    #声音文件被使用 
    UPLOAD_SERVICE.updateTrackUsed(track.id, track.transcode_state, image_ids, fileid.to_i, track.play_path_64.present? && track.waveform.present?)
    
    # 声音富文本
    cleaned_rich_intro = clean_html(rich_intro) if rich_intro.present?
    cleaned_lyric = CGI.escapeHTML(Sanitize.clean(lyric, { elements: %w(br) }))[0, 5000] if lyric.present?

    track_rich = TrackRich.stn(track.id).where(track_id: track.id).first
    if track_rich
      track_rich.update_attributes(rich_intro: cleaned_rich_intro, lyric: cleaned_lyric)
    else
      TrackRich.create(track_id: track.id, rich_intro: cleaned_rich_intro, lyric: cleaned_lyric)
    end

    # 块记录
    TrackBlock.create(track_id: track.id, duration: track.duration) if track.duration
    # 声音记录
    track_record = TrackRecord.create(
      track_id: track.id,
      track_uid: @current_uid, # 原声音发布者
      track_upload_source: track.upload_source,
      uid: @current_uid,  
      nickname: @current_user.nickname,
      avatar_path: @current_user.logoPic,
      is_v: @current_user.isVerified,
      dig_status: track.dig_status,
      human_category_id: @current_user.vCategoryId,
      approved_at: track.approved_at,
      op_type: 1,
      is_crawler: track.is_crawler,
      upload_source: track.upload_source,
      user_source: track.user_source,
      category_id: track.category_id,
      music_category: track.music_category,
      download_path: track.download_path,
      duration: track.duration,
      play_path: track.play_path,
      play_path_32: track.play_path_32,
      play_path_64: track.play_path_64,
      play_path_128: track.play_path_128,
      transcode_state: track.transcode_state,
      mp3size: track.mp3size,
      mp3size_32: track.mp3size_32,
      mp3size_64: track.mp3size_64,
      tags: track.tags,
      title: track.title,
      intro: track.intro,
      short_intro: track.short_intro,
      rich_intro: track.rich_intro,
      is_public: track.is_public,
      is_publish: track.is_publish,
      singer: track.singer,
      singer_category: track.singer_category,
      author: track.author,
      arrangement: track.arrangement,
      post_production: track.post_production,
      resinger: track.resinger,
      announcer: track.announcer,
      composer: track.composer,
      allow_download: track.allow_download,
      allow_comment: track.allow_comment,
      cover_path: track.cover_path,
      album_id: track.album_id,
      album_title: track.album_title,
      album_cover_path: track.album_cover_path,
      waveform: track.waveform,
      upload_id: track.upload_id,
      inet_aton_ip: track.inet_aton_ip,
      status: track.status,
      explore_height: track.explore_height
    )

    if track.is_public && track.status == 1
      $counter_client.incr(Settings.counter.user.tracks, track.uid, 1)
      if track.album_id
        $counter_client.incr(Settings.counter.album.tracks, track.album_id, 1)
      end
    end

    # 如果添加到专辑，更新专辑排序
    if album
      if album.tracks_order
        if album.is_records_desc
          album.tracks_order = ( [track_record.id] + album.tracks_order.split(",") ).join(",")
        else
          album.tracks_order = album.tracks_order.split(",").push(track_record.id).join(",")
        end
      end
      album.save
      CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,false,request.user_agent,[track_record.id],nil,nil,nil,nil,[sharing_to, share_content],'sound')
    else
      if track.is_public && track.status == 1
        CoreAsync::TrackOnWorker.perform_async(:track_on, track.id, true, [sharing_to, share_content], nil)
        $rabbitmq_channel.fanout(Settings.topic.track.created, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(user_agent: request.user_agent, is_feed: true)), content_type: 'text/plain', persistent: true)
        bunny_logger = ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
        bunny_logger.info "track.created.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"
      end
    end
  end

  #定时上传单条声音 [ 可选 添加到指定专辑 ]
  def delayed_upload_single_track(datetime,fileid,transcode_data,title,user_source,category_id,is_public,images,intro,rich_intro,tags,music_category,singer,singer_category,author,composer,arrangement,post_production,lyric,resinger,announcer,sharing_to,share_content,album)
    
    current_now = Time.now
    task_count_tag = current_now.to_i
    default_status = calculate_default_status(@current_user)
    cleaned_rich_intro = clean_html(rich_intro) if rich_intro.present?
    cleaned_lyric = CGI.escapeHTML(Sanitize.clean(lyric, { elements: %w(br) }))[0, 5000] if lyric.present?

    track_origin = Track.new
    track_origin.upload_source = 2 # 网站
    track_origin.is_crawler = false
    track_origin.uid = @current_uid # 源发布者
    track_origin.nickname = @current_user.nickname
    track_origin.avatar_path = @current_user.logoPic
    track_origin.is_v = @current_user.isVerified
    track_origin.dig_status = calculate_dig_status(@current_user)
    track_origin.human_category_id = @current_user.vCategoryId
    track_origin.approved_at = current_now if default_status == 1
    track_origin.title = title
    track_origin.user_source = user_source
    track_origin.category_id = category_id
    track_origin.music_category = music_category
    track_origin.tags = tags
    track_origin.intro = intro
    track_origin.short_intro = intro[0, 100]
    track_origin.rich_intro = cut_intro(intro)
    track_origin.singer = singer
    track_origin.singer_category = singer_category
    track_origin.author = author
    track_origin.arrangement = arrangement
    track_origin.post_production = post_production
    track_origin.resinger = resinger
    track_origin.announcer = announcer
    track_origin.composer = composer
    track_origin.is_publish = true
    track_origin.is_public = is_public
    track_origin.allow_download =  true
    track_origin.allow_comment = true
    track_origin.transcode_state = transcode_data['transcode_state']
    track_origin.mp3size = transcode_data['paths']['origin_size']
    track_origin.upload_id = transcode_data['upload_id']
    track_origin.download_path = transcode_data['paths']['aacplus32']
    track_origin.download_size = transcode_data['paths']['aacplus32_size']
    track_origin.play_path = transcode_data['paths']['origin_path']
    track_origin.play_path_32 = transcode_data['paths']['mp332']
    track_origin.mp3size_32 = transcode_data['paths']['mp332_size']
    track_origin.play_path_64 = transcode_data['paths']['mp364']
    track_origin.mp3size_64 = transcode_data['paths']['mp364_size']
    track_origin.duration = transcode_data['duration']
    track_origin.waveform = transcode_data['waveform']
    track_origin.inet_aton_ip = inet_aton(get_client_ip)
    track_origin.status = 2

    if album
      if album.cover_path
        # 把专辑封面用作声音默认封面
        pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
        default_cover_path = pic['origin']
        default_cover_exlore_height = pic['180n_height']
      end

      track_origin.album_id = album.id
      track_origin.album_title = album.title
      track_origin.album_cover_path = album.cover_path
      track_origin.cover_path = default_cover_path
      track_origin.explore_height = default_cover_exlore_height
    end

    if images.present?
      create_images,image_index = [],0
      images.each do |image|
        begin
        covers = Yajl::Parser.parse(image)
        if covers['status'] and covers['status']!=false and covers['data'] and cover=covers['data'].first and cover_track=cover['uploadTrack'] and paths = cover['processResult']
          create_images << [cover_track['id'].to_i, image_index+1, paths["origin"], paths["180n_height"]]
          if image_index.zero?
            track_origin.cover_path = paths["origin"]
            track_origin.explore_height = paths["180n_height"]
          end
          image_index += 1
        end
        rescue
          next
        end
      end
    end

    track_origin.save

    if create_images.present?
      image_ids = []
      create_images.each do |image_id,order_num,picture_path,explore_height|
        TrackPicture.create(track_id:track_origin.id,uid:@current_uid,picture_path:picture_path,explore_height:explore_height,order_num:order_num)
        image_ids << image_id
      end
    end

    UPLOAD_SERVICE.updateTrackUsed(track_origin.id, track_origin.transcode_state, image_ids, fileid.to_i, track_origin.play_path_64.present? && track_origin.waveform.present?)

    track = DelayedTrack.new
    track.track_id = track_origin.id
    track.fileid = fileid
    track.status = default_status
    track.publish_at = datetime
    track.task_count_tag = task_count_tag
    track.upload_source = track_origin.upload_source
    track.is_crawler = track_origin.is_crawler
    track.uid = track_origin.uid
    track.nickname = track_origin.nickname
    track.avatar_path = track_origin.avatar_path
    track.is_v = track_origin.is_v
    track.dig_status = track_origin.dig_status
    track.human_category_id = track_origin.human_category_id
    track.approved_at = track_origin.approved_at
    track.title = track_origin.title
    track.user_source = track_origin.user_source
    track.category_id = track_origin.category_id
    track.music_category = track_origin.music_category
    track.tags = track_origin.tags
    track.intro = track_origin.intro
    track.short_intro = track_origin.short_intro
    track.rich_intro = track_origin.rich_intro
    track.singer = track_origin.singer
    track.singer_category = track_origin.singer_category
    track.author = track_origin.author
    track.arrangement = track_origin.arrangement
    track.post_production = track_origin.post_production
    track.resinger = track_origin.resinger
    track.announcer = track_origin.announcer
    track.composer = track_origin.composer
    track.is_publish = track_origin.is_publish
    track.is_public = track_origin.is_public
    track.lyric = track_origin.lyric
    track.allow_download =  track_origin.allow_download
    track.allow_comment = track_origin.allow_comment
    track.transcode_state = track_origin.transcode_state
    track.mp3size = track_origin.mp3size
    track.upload_id = track_origin.upload_id
    track.download_path = track_origin.download_path
    track.download_size = track_origin.download_size
    track.play_path = track_origin.play_path
    track.play_path_32 = track_origin.play_path_32
    track.mp3size_32 = track_origin.mp3size_32
    track.play_path_64 = track_origin.play_path_64
    track.mp3size_64 = track_origin.mp3size_64
    track.duration = track_origin.duration
    track.waveform = track_origin.waveform
    track.inet_aton_ip = track_origin.inet_aton_ip

    if album
      dalbum = DelayedAlbum.new
      dalbum.uid = @current_uid
      dalbum.nickname = album.nickname
      dalbum.avatar_path = album.avatar_path
      dalbum.is_v = album.is_v
      dalbum.dig_status = album.dig_status
      dalbum.human_category_id = album.human_category_id
      dalbum.title = album.title
      dalbum.intro = album.intro
      dalbum.short_intro = album.short_intro
      dalbum.tags = album.tags
      dalbum.user_source = album.user_source
      dalbum.category_id = album.category_id
      dalbum.music_category  = album.music_category
      dalbum.is_finished = album.is_finished
      dalbum.cover_path = album.cover_path
      dalbum.is_records_desc = album.is_records_desc
      dalbum.is_public = album.is_public
      dalbum.is_publish = true
      dalbum.publish_at = datetime
      dalbum.status = default_status
      dalbum.rich_intro = cut_intro(rich_intro)
      dalbum.save

      track.delayed_album_id = dalbum.id # 临时专辑id
    end

    track.save

    mqMessage = {
      track_id: track_origin.id,
      delayed_track_ids: [track.id],
      delete_delayed_album_id: dalbum && dalbum.id,
      delayed_publish_at: datetime,
      share: [sharing_to, share_content],
      user_agent: request.user_agent,
      rich_intro: cleaned_rich_intro
    }
    $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain', persistent: true)
  end

  #上传多条声音·添加到指定专辑
  def upload_tracks_into_album(album,zipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,datetime)
    album_rich = TrackSetRich.stn(album.id).where(track_set_id: album.id).first
    cleaned_rich_intro = (album_rich && album.rich_intro.to_s) || ''
    if datetime
      delayedzipfiles = []
      zipfiles.each do |fid,title|
        if !['r','m'].include?(fid[0])
          delayedzipfiles << [fid,title]
        end
      end
      delayed_create_album_tracks(datetime,album,delayedzipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)
    else
      create_album_tracks(album,zipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)
    end
  end

  #上传单张专辑·多条声音
  def create_album_and_tracks(zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
    album = Album.new
    album.uid = @current_uid
    album.nickname = @current_user.nickname
    album.avatar_path = @current_user.logoPic
    album.is_v = @current_user.isVerified
    album.dig_status = calculate_dig_status(@current_user)
    album.human_category_id = @current_user.vCategoryId
    album.title = title
    album.intro = intro
    album.short_intro = intro ? intro[0, 100] : nil
    album.rich_intro = cut_intro(rich_intro)
    album.tags = tags
    album.user_source = user_source.to_i
    album.category_id = category_id
    album.music_category = music_category
    album.cover_path = default_cover_path
    album.is_publish = true
    album.is_public = true
    album.is_records_desc = is_records_desc
    album.is_finished = is_finished
    album.status = calculate_default_status(@current_user)
    album.save

    # 专辑富文本
    cleaned_rich_intro = clean_html(rich_intro) if rich_intro.present?

    setrich = TrackSetRich.stn(album.id).where(track_set_id: album.id).first
    if setrich
      setrich.update_attributes(rich_intro: cleaned_rich_intro)
    else
      TrackSetRich.create(track_set_id: album.id, rich_intro: cleaned_rich_intro)
    end

    # 存专辑下的声音
    response = manage_album_tracks(album, zipfiles, p_transcode_res, default_cover_path, default_cover_exlore_height,cleaned_rich_intro)

    if album.status == 1
      $counter_client.incr(Settings.counter.user.albums, album.uid, 1)
      new_tracks_size = response[:create].size
      if new_tracks_size > 0
        $counter_client.incr(Settings.counter.user.albums, album.uid, 1)
        $counter_client.incr(Settings.counter.user.tracks, album.uid, new_tracks_size)
        $counter_client.incr(Settings.counter.album.tracks, album.id, new_tracks_size)
      end
    end

    CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,true,request.user_agent,response[:create],response[:update],response[:move],response[:destroy],nil,[sharing_to, share_content],nil)

    true
  end

  #定时上传专辑·多条声音
  def delayed_create_album_and_tracks(datetime,zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)

    album = DelayedAlbum.new
    album.uid = @current_uid
    album.nickname = @current_user.nickname
    album.avatar_path = @current_user.logoPic
    album.is_v = @current_user.isVerified
    album.dig_status = calculate_dig_status(@current_user)
    album.human_category_id = @current_user.vCategoryId
    album.title = title
    album.intro = intro
    album.short_intro = intro && intro[0, 100]
    album.tags = tags
    album.user_source = user_source
    album.category_id = category_id
    album.music_category  = music_category
    album.is_finished = is_finished
    album.cover_path = default_cover_path
    album.is_public = true
    album.is_publish = true
    album.is_records_desc = is_records_desc
    album.publish_at = datetime
    album.status = calculate_default_status(@current_user)
    album.rich_intro = cut_intro(rich_intro)
    album.save

    REDIS.incr("#{Settings.delayedpublishalbumcount}.#{Time.new.strftime('%F')}")

    new_fileid_idx, delayed_track_ids = 0, []
    task_count_tag = Time.now.to_i
    zipfiles.each do |fid, title|
      next if fid.blank?
      next if ['r','m'].include?(fid[0])
      track = DelayedTrack.new
      track.task_count_tag = task_count_tag
      d = p_transcode_res['data'][new_fileid_idx]
      track.transcode_state = d['transcode_state']
      track.mp3size = d['paths']['origin_size']
      track.upload_id = d['upload_id']
      track.download_path = d['paths']['aacplus32']
      track.download_size = d['paths']['aacplus32_size']
      track.play_path = d['paths']['origin_path']
      track.play_path_32 = d['paths']['mp332']
      track.mp3size_32 = d['paths']['mp332_size']
      track.play_path_64 = d['paths']['mp364']
      track.mp3size_64 = d['paths']['mp364_size']
      track.duration = d['duration']
      track.waveform = d['waveform']
      track.is_crawler = false
      track.upload_source = 2 # 网站上传
      track.uid = album.uid # 源发布者id
      track.nickname = album.nickname # 源发布者昵称
      track.avatar_path = album.avatar_path #源发布者头像
      track.is_v = album.is_v
      track.dig_status = album.dig_status # 发现页可见
      track.human_category_id = album.human_category_id
      track.approved_at = Time.now
      track.album_id = album.id # 源专辑id
      track.album_title = album.title # 源专辑标题
      track.album_cover_path = album.cover_path
      track.title = title
      track.category_id = album.category_id
      track.music_category = album.music_category
      track.tags = album.tags
      track.intro = album.intro
      track.short_intro = album.short_intro
      track.rich_intro = album.rich_intro
      track.user_source = album.user_source
      track.cover_path = default_cover_path
      track.explore_height = default_cover_exlore_height
      track.is_public = album.is_public
      track.is_publish = true
      track.delayed_album_id = album.id
      track.publish_at = datetime
      track.fileid = fid.to_i
      track.inet_aton_ip = inet_aton(get_client_ip)
      track.status = album.status
      track.save

      new_fileid_idx += 1

      REDIS.incr("#{Settings.delayedpublishtrackcount}.#{Time.new.strftime('%F')}")

      delayed_track_ids << track.id
    end

    cleaned_rich_intro = clean_html(rich_intro) if rich_intro.present?

    # 定时发布queue
    mqMessage = {
      delayed_track_ids: delayed_track_ids,
      delayed_album_id: album.id.to_s,
      delayed_publish_at: datetime,
      share: [sharing_to, share_content],
      user_agent: request.user_agent,
      is_records_desc: is_records_desc,
      rich_intro: cleaned_rich_intro
    }
    $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain', persistent: true)

    true
  end

  #修改单条声音 [ 可选 添加进专辑,转移到另一个专辑,转出当前专辑 ]
  def update_single_track(track,record,album,title,intro,is_public,rich_intro,lyric,singer,singer_category,author,composer,arrangement,post_production,resinger,announcer,music_category,images,destroy_images)
    cache_is_public  = track.is_public
    cache_album_id = track.album_id

    cleaned_rich_intro = clean_html(rich_intro)
    cleaned_lyric = CGI.escapeHTML(Sanitize.clean(lyric, { elements: %w(br) }))[0, 5000] if lyric.present?

    temp = {
      title: title,
      intro: intro,
      short_intro: intro && intro[0, 100],
      rich_intro: cut_intro(rich_intro),
      singer: singer,
      singer_category: singer_category,
      author: author,
      composer: composer,
      arrangement: arrangement,
      post_production: post_production,
      resinger: resinger,
      announcer: announcer,
      music_category: music_category,
      is_public: cache_is_public || is_public
    }

    #更新声音图片信息
    destroy_images.each do |picture_id|
      picture_id = picture_id.to_i
      track_picture = TrackPicture.stn(track.id).where(id:picture_id,track_id:track.id).first
      track_picture.destroy if track_picture
    end if destroy_images.present?

    if images.present?
      create_images,image_index = [],0
      images.each do |image|
        next if image.to_s=="0"
        if (picture_id=image.to_i)>0
          track_picture = TrackPicture.stn(track.id).where(id:picture_id,track_id:track.id).first
          if track_picture
            track_picture.update_attribute('order_num',image_index+1)
            if image_index.zero?
              temp[:cover_path] = track_picture.picture_path
              temp[:explore_height] = track_picture.explore_height
            end
            image_index += 1
          end
        else
          begin
          covers = Yajl::Parser.parse(image)
          if covers['status'] and covers['status']!=false and covers['data'] and cover=covers['data'].first and cover_track=cover['uploadTrack'] and paths = cover['processResult']
            create_images << [cover_track['id'].to_i, image_index+1, paths["origin"], paths["180n_height"]]
            if image_index.zero?
              temp[:cover_path] = paths["origin"]
              temp[:explore_height] = paths["180n_height"]
            end
            image_index += 1
          end
          rescue
            next
          end
        end
      end
    else
      temp[:cover_path] = nil
    end

    if album # 更新专辑信息
      temp[:album_id] = album.id
      temp[:album_title] = album.title
      temp[:album_cover_path] = album.cover_path
    elsif cache_album_id
      temp[:album_id] = nil
      temp[:album_title] = nil
      temp[:album_cover_path] = nil
    end

    track.update_attributes(temp)
    record.update_attributes(temp)

    if create_images.present?
      image_ids = []
      create_images.each do |image_id,order_num,picture_path,explore_height|
        TrackPicture.create(track_id:track.id,uid:@current_uid,picture_path:picture_path,explore_height:explore_height,order_num:order_num)
        image_ids << image_id
      end
      UPLOAD_SERVICE.updateTrackUsed(track.id, track.transcode_state, image_ids, nil, nil)
    end

    track_rich = TrackRich.stn(track.id).where(track_id: track.id).first
    if track_rich
      track_rich.update_attributes(rich_intro: cleaned_rich_intro, lyric: cleaned_lyric)
    else
      TrackRich.create(track_id: track.id, rich_intro: cleaned_rich_intro, lyric: cleaned_lyric)
    end
    
    if album
      if album.tracks_order
        if album.is_records_desc
          album.tracks_order = ( [record.id] + album.tracks_order.split(",") ).join(",")
        else
          album.tracks_order = album.tracks_order.split(",").push(record.id).join(",")
        end
        album.save
      end
      CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,false,request.user_agent,nil,nil,[[record.id, cache_album_id]],nil,nil,nil,nil)
    elsif cache_album_id
      past_album = Album.stn(@current_uid).where(id: cache_album_id, uid: @current_uid).first
      if past_album
        past_album.tracks_order &&= past_album.tracks_order.split(',').delete_if{ |id| id == record.id }.join(",")
        past_album.save

        if track and track.is_public
          $counter_client.decr(Settings.counter.album.tracks, past_album.id, 1)
          plays = $counter_client.get(Settings.counter.track.plays, track.id)
          $counter_client.decr(Settings.counter.album.plays, past_album.id, plays) if plays > 0
        end

        mqMessage = { id: past_album.id, user_agent: request.user_agent }
        CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,past_album.id,false,request.user_agent,nil,nil,nil,nil,nil,nil,nil)
        $rabbitmq_channel.queue('album.updated.dj', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain')
      end
    end

    if cache_is_public
      $rabbitmq_channel.fanout(Settings.topic.track.updated, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash), content_type: 'text/plain', persistent: true)
      bunny_logger = ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
      bunny_logger.info "track.updated.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"

      if track.is_public && track.status == 1 && !@current_user.isVerified
        ApprovingTrack.where(track_id: track.id, is_update: true).destroy_all
        uag = UidApproveGroup.where(uid: track.uid).first
        ApprovingTrack.create(album_cover_path: track.album_cover_path,
          album_id: track.album_id,
          album_title: track.album_title,
          approve_group_id: uag && uag.approve_group_id,
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
          tags: track.tags,
          is_update: true
        )
      end
    elsif track.is_public
      CoreAsync::TrackOnWorker.perform_async(:track_on, track.id, false, nil, nil)
      $rabbitmq_channel.fanout(Settings.topic.track.created, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(user_agent: request.headers['user_agent'], is_feed: true)), content_type: 'text/plain', persistent: true)
      bunny_logger = ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
      bunny_logger.info "track.created.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"
    end   
  end

  #修改单张专辑·多条声音
  def update_album_and_tracks(album,title,intro,rich_intro,category_id,music_category,is_records_desc,is_finished,zipfiles,sharing_to,share_content,p_transcode_res,is_image_change,default_cover_path,default_cover_exlore_height,datetime)
    
    cleaned_rich_intro = clean_html(rich_intro) if rich_intro.present?

    update_album_columns(album,title,intro,rich_intro,cleaned_rich_intro,category_id,music_category,is_records_desc,is_finished,is_image_change,default_cover_path)
    
    if datetime
      delayedzipfiles,zipfiles2 = [],[]
      zipfiles.each do |fid,title|
        if ['r','m'].include?(fid[0])
          zipfiles2 << [fid,title]
        else
          delayedzipfiles << [fid,title]
        end
      end
      delayed_create_album_tracks(datetime,album,delayedzipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)
    else
      zipfiles2 = zipfiles
    end

    response = manage_album_tracks(album, zipfiles2, p_transcode_res, default_cover_path, default_cover_exlore_height,cleaned_rich_intro)

    if album.status == 1
      incr_count = response[:create].size + response[:move].size - response[:destroy].size
      if incr_count > 0
        $counter_client.incr(Settings.counter.user.tracks, album.uid, incr_count)
        $counter_client.incr(Settings.counter.album.tracks, album.id, incr_count)
      elsif incr_count < 0
        decr_count = incr_count.abs
        $counter_client.decr(Settings.counter.user.tracks, album.uid, decr_count)
        $counter_client.decr(Settings.counter.album.tracks, album.id, decr_count)
      end
    end

    CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,false,request.user_agent,response[:create],response[:update],response[:move],response[:destroy],nil,[sharing_to, share_content],nil)

    true
  end

  # 参数验证 返回错误消息数组
  def catch_upload_basic_errors(title, user_source, category_id, intro, tags)
    errors = []
    if title.blank?
      errors << ['title', '标题填写有误']
    end

    if ![1,2].include?(user_source.to_i)
      errors << ['user_source', '来源设置有误']
    end

    if category_id.to_i <= 0
      errors << ['category_id', '类别设置有误']
    end

    if intro.present? and intro.size > 9000
      errors << ['intro', '简介填写有误']
    end

    if tags.present?
      t_arr = tags.split(",")
      if t_arr.length > 5
        errors <<  ['tags', '标签不能超过5个']
      else
        t_arr.each do |tag|
          if tag.length > 50
            errors << ['tags', '标签长度不能超过50']
            break
          end
        end
      end
    end

    errors
  end

  #敏感词检测
  def filter_hash(type, user, ip, hash, is_check_freq = false)

    thrift_hash = {}
    hash.each do |key,value|
      thrift_hash[key.to_s]  = value.to_s if value.present? and value.present?
    end

    if !is_check_freq || user.isVerified
      ret = $wordfilter_client.onlyWordFilters(type, user.uid, ip, thrift_hash)
    else
      ret = $wordfilter_client.mutilWordFilter(type, user.uid, ip, thrift_hash)
    end
    # {error:0} || {error:非0, part:"哪部分内容"}
    errno = ret.error.to_i
    errno == 0 ? {} : { errno => ret.part }
  end


  private


  def update_album_columns(album,title,intro,rich_intro,cleaned_rich_intro,category_id,music_category,is_records_desc,is_finished,is_image_change,default_cover_path)
    
    tmp_attrs = {
      title: title,
      nickname: @current_user.nickname,
      intro: intro,
      short_intro: intro && intro[0, 100],
      rich_intro: cut_intro(rich_intro),
      category_id: category_id,
      music_category: music_category,
      is_records_desc: is_records_desc,
      is_finished: is_finished
    }
    tmp_attrs[:cover_path] = default_cover_path if is_image_change
    album.update_attributes(tmp_attrs)

    # 专辑富文本
    setrich = TrackSetRich.stn(album.id).where(track_set_id: album.id).first

    if setrich
      setrich.update_attributes(rich_intro: cleaned_rich_intro)
    else
      TrackSetRich.create(track_set_id: album.id, rich_intro: cleaned_rich_intro)
    end
    true
  end

  def create_album_tracks(album,uploadzipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)

    return if uploadzipfiles.blank?

    create_record_ids = []

    new_fileid_idx = 0
    uploadzipfiles.each do |fid, title|
      transcode_data = p_transcode_res['data'][new_fileid_idx]
      new_fileid_idx += 1
      if result = create_album_track(album,fid,title,transcode_data,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)
        create_record_ids << result[:record]
      end
    end

    if new_records.size > 0 and album.tracks_order
      if is_records_desc || album.is_records_desc
        album.tracks_order = ( new_records.map{|r| r.id} + album.tracks_order.split(",") ).join(",")
      else
        album.tracks_order = ( album.tracks_order.split(",") + new_records.map{|r| r.id} ).join(",")
      end
      album.save
    end

    if album.status == 1 and (new_tracks_size=create_record_ids.size)>0
      $counter_client.incr(Settings.counter.user.tracks, album.uid, new_tracks_size)
      $counter_client.incr(Settings.counter.album.tracks, album.id, new_tracks_size)
    end

    CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,false,request.user_agent,create_record_ids,nil,nil,nil,nil,[sharing_to, share_content],nil)
  end

  def delayed_create_album_tracks(datetime,album,delayedzipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)

    return if delayedzipfiles.blank?

    dalbum = DelayedAlbum.new
    dalbum.uid = @current_uid
    dalbum.nickname = @current_user.nickname
    dalbum.avatar_path = @current_user.logoPic
    dalbum.is_v = @current_user.isVerified
    dalbum.dig_status = calculate_dig_status(@current_user)
    dalbum.human_category_id = @current_user.vCate
    dalbum.title = album.title
    dalbum.intro = album.intro
    dalbum.short_intro = album.short_intro
    dalbum.tags = album.tags
    dalbum.user_source = album.user_source
    dalbum.category_id = album.category_id
    dalbum.music_category  = album.music_category
    dalbum.is_finished = album.is_finished    
    dalbum.cover_path = album.cover_path
    dalbum.is_public = album.is_public
    dalbum.is_records_desc = is_records_desc || album.is_records_desc
    dalbum.is_publish = album.is_publish
    dalbum.publish_at = datetime
    dalbum.status = album.status
    dalbum.rich_intro = album.rich_intro
    dalbum.save
    
    task_count_tag = Time.now.to_i

    # 存专辑下的声音
    track_ids,new_fileid_idx = [],0
    delayedzipfiles.each do |fid,title|
      
      transcode_data = p_transcode_res['data'][new_fileid_idx]

      track = DelayedTrack.new
      track.task_count_tag = task_count_tag
      track.transcode_state = transcode_data['transcode_state']
      track.mp3size = transcode_data['paths']['origin_size']
      track.upload_id = transcode_data['upload_id']
      track.download_path = transcode_data['paths']['aacplus32']
      track.download_size = transcode_data['paths']['aacplus32_size']
      track.play_path = transcode_data['paths']['origin_path']
      track.play_path_32 = transcode_data['paths']['mp332']
      track.mp3size_32 = transcode_data['paths']['mp332_size']
      track.play_path_64 = transcode_data['paths']['mp364']
      track.mp3size_64 = transcode_data['paths']['mp364_size']
      track.duration = transcode_data['duration']
      track.waveform = transcode_data['waveform']
      track.is_crawler = false
      track.upload_source = 2 # 网站上传
      track.uid = @current_user..uid # 源发布者id
      track.nickname = @current_user.nickname # 源发布者昵称
      track.avatar_path = @current_user.logoPic #源发布者头像
      track.is_v = @current_user.isVerified
      track.dig_status = calculate_dig_status(@current_user) # 发现页可见
      track.human_category_id = @current_user.vCategoryId
      track.approved_at = Time.now
      track.album_id = album.id # 源专辑id
      track.delayed_album_id = dalbum.id # 临时专辑id
      track.album_title = album.title # 源专辑标题
      track.album_cover_path = album.cover_path
      track.title = title
      track.category_id = album.category_id
      track.music_category = album.music_category
      track.tags = album.tags || ""
      track.intro = album.intro
      track.short_intro = album.short_intro
      track.rich_intro = album.rich_intro
      track.user_source = album.user_source
      track.cover_path = default_cover_path
      track.explore_height = default_cover_exlore_height
      track.is_public = album.is_public
      track.is_publish = true
      track.publish_at = datetime
      track.fileid = fid.to_i
      track.inet_aton_ip = inet_aton(get_client_ip)
      track.status = album.status
      track.save

      UPLOAD_SERVICE.updateTrackUsed(nil, track.transcode_state, [], fid.to_i, true)

      REDIS.incr("#{Settings.delayedpublishtrackcount}.#{Time.new.strftime('%F')}")

      new_fileid_idx += 1
      track_ids << track.id
    end

    mqMessage = {
      delayed_track_ids: track_ids,
      delete_delayed_album_id: dalbum.id,
      delayed_publish_at: datetime,
      share: [sharing_to, share_content],
      user_agent: request.user_agent,
      is_records_desc: dalbum.is_records_desc,
      rich_intro: cleaned_rich_intro
    }
    $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain', persistent: true)

    REDIS.incr("#{Settings.delayedpublishcount}.#{Time.new.strftime('%F')}")
  end

  # 处理专辑下的声音
  # fileids对应页面元素： 123: 新上传, m123: (移动的)track_id, r123: (专辑里原有的)record_id
  def manage_album_tracks(album, zipfiles, p_transcode_res, default_cover_path, default_cover_exlore_height, cleaned_rich_intro, record_ids_to_destroy = [])

    response = {create:[],update:[],move:[]}
    response[:destroy] = destroy_album_tracks(album,record_ids_to_destroy)

    all_records,new_fileid_idx = [],0
    zipfiles.each do |fid, title|
      case fid[0] when 'r'
        next unless (record_id=fid[1..-1].to_i) > 0
        if result = update_album_track(album,record_id,title)
          response[:update] << result[:update] if result[:update] #maybe not change
          all_records << result[:record]
        end
      when 'm'
        next unless (record_id=fid[1..-1].to_i) > 0
        if result = move_album_track(album,record_id,title)
          response[:move] << result[:move]
          all_records << result[:record]
        end
      else
        transcode_data = p_transcode_res['data'][new_fileid_idx]
        new_fileid_idx += 1
        if result = create_album_track(album,fid,title,transcode_data,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)
          response[:create] << result[:create]
          all_records << result[:record]
        end
      end
    end

    # 更新专辑声音排序和最新更新声音
    if all_records.size > 0
      album.tracks_order = all_records.map{|r| r.id}.join(',')
      latest_record = all_records.sort{|x, y| y.created_at <=> x.created_at }.first
      album.last_uptrack_at = latest_record.created_at
      album.last_uptrack_id = latest_record.track_id
      album.last_uptrack_title = latest_record.title
      album.last_uptrack_cover_path = latest_record.cover_path
    else
      album.tracks_order = nil
      album.last_uptrack_at = nil
      album.last_uptrack_id = nil
      album.last_uptrack_title = nil
      album.last_uptrack_cover_path = nil
    end
    album.save

    response
  end

  def destroy_album_tracks(album,record_ids)
    destroy_track_ids = []
    record_ids.each do |record_id|
      record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
      if record
        if record.op_type == 1 # 软删声音
          track = Track.stn(record.track_id).where(id: record.track_id).first
          if track
            track.update_attribute(:is_deleted, true)
            destroy_track_ids << track.id
          end
        end
        record.update_attribute(:is_deleted, true)
      end
    end
    
    destroy_track_ids
  end

  def update_album_track(album,record_id,title)
    record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
    return false unless record

    response = {}
    if record.uid == record.track_uid
      track = Track.stn(record.track_id).where(uid: record.track_uid, id: record.track_id).first
      return false unless track

      record.title = title if title.present?
      record.album_title = album.title
      record.album_cover_path = album.cover_path
      record.is_public = album.is_public
      record.save if record.changed?

      track.title = title
      track.album_title = album.title
      track.album_cover_path = album.cover_path
      track.is_public = album.is_public
      if track.changed?
        track.save
        response[:update] = track.id
      end
    end
    response[:record] = record
    response
  end

  def move_album_track(album,record_id,title)

    record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
    return false unless record

    track = Track.stn(record.track_id).where(uid: album.uid, id: record.track_id, is_deleted: false, status: 1).first
    return false unless track

    response = {}

    cache_album_id = track.album_id

    track.title = title
    track.album_id = album.id
    track.album_title = album.title
    track.album_cover_path = album.cover_path
    track.is_public = album.is_public

    record.title = title
    record.album_id = album.id
    record.album_title = album.title
    record.album_cover_path = album.cover_path
    record.is_public = album.is_public     

    track.save
    record.save

    response[:move] = [ record.id, cache_album_id ]
    response[:record] = record

    response
  end

  def create_album_track(album,fid,title,transcode_data,default_cover_path,default_cover_exlore_height,cleaned_rich_intro)

    response = {}

    track = Track.new
    track.transcode_state = transcode_data['transcode_state']
    track.mp3size = transcode_data['paths']['origin_size']
    track.upload_id = transcode_data['upload_id']
    track.download_path = transcode_data['paths']['aacplus32']
    track.download_size = transcode_data['paths']['aacplus32_size']
    track.play_path = transcode_data['paths']['origin_path']
    track.play_path_32 = transcode_data['paths']['mp332']
    track.mp3size_32 = transcode_data['paths']['mp332_size']
    track.play_path_64 = transcode_data['paths']['mp364']
    track.mp3size_64 = transcode_data['paths']['mp364_size']
    track.duration = transcode_data['duration']
    track.waveform = transcode_data['waveform']
    track.is_crawler = false
    track.upload_source = 2 # 网站上传
    track.uid = @current_uid # 源发布者id
    track.nickname = @current_user.nickname # 源发布者昵称
    track.avatar_path = @current_user.logoPic #源发布者头像
    track.is_v = @current_user.isVerified
    track.dig_status = calculate_dig_status(@current_user) # 发现页可见
    track.human_category_id = @current_user.vCategoryId
    track.approved_at = Time.now
    track.album_id = album.id # 源专辑id
    track.album_title = album.title # 源专辑标题
    track.album_cover_path = album.cover_path
    track.title = title
    track.category_id = album.category_id
    track.music_category = album.music_category
    track.tags = album.tags
    track.intro = album.intro
    track.short_intro = album.short_intro
    track.rich_intro = album.rich_intro
    track.user_source = album.user_source
    track.cover_path = default_cover_path
    track.explore_height = default_cover_exlore_height
    track.is_public = album.is_public
    track.is_publish = true

    track.inet_aton_ip = inet_aton(get_client_ip)
    track.status = album.status
    track.save

    UPLOAD_SERVICE.updateTrackUsed(track.id, track.transcode_state, [], fid.to_i, true)

    # 块记录
    TrackBlock.create(track_id: track.id, duration: track.duration) if track.duration

    # 富文本
    TrackRich.create(track_id: track.id, rich_intro: cleaned_rich_intro) if cleaned_rich_intro.present?
    
    # 创建record记录
    record = TrackRecord.create(op_type: 1,
      track_id: track.id,
      track_uid: track.uid,
      track_upload_source: track.upload_source,
      is_crawler: track.is_crawler,
      uid: track.uid, 
      nickname: track.nickname,
      avatar_path: track.avatar_path, 
      is_v: track.is_v,
      dig_status: track.dig_status,
      human_category_id: track.human_category_id,
      approved_at: track.approved_at,
      upload_source: track.upload_source,
      user_source: track.user_source, 
      category_id: track.category_id,
      music_category: track.music_category,
      download_path: track.download_path,
      duration: track.duration,
      play_path: track.play_path,
      play_path_32: track.play_path_32,
      play_path_64: track.play_path_64,
      play_path_128: track.play_path_128,
      transcode_state: track.transcode_state, 
      mp3size: track.mp3size,
      mp3size_32: track.mp3size_32,
      mp3size_64: track.mp3size_64,
      tags: track.tags, 
      title: track.title, 
      intro: track.intro,
      short_intro: track.short_intro,
      rich_intro: track.rich_intro,
      is_public: track.is_public,
      is_publish: track.is_publish,
      singer: track.singer,
      singer_category: track.singer_category,
      author: track.author,
      arrangement: track.arrangement,
      post_production: track.post_production,
      resinger: track.resinger,
      announcer: track.announcer,
      composer: track.composer,
      allow_download: track.allow_download,
      allow_comment: track.allow_comment,
      cover_path: track.cover_path, 
      album_id: track.album_id, 
      album_title: track.album_title, 
      album_cover_path: track.album_cover_path,
      waveform: track.waveform,
      upload_id: track.upload_id,
      inet_aton_ip: track.inet_aton_ip,
      status: track.status,
      explore_height: track.explore_height
    )

    response[:create] = record.id
    response[:record] = record

    response
  end

end