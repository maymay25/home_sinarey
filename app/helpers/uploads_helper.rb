module UploadsHelper

  #创建专辑
  def create_album_and_tracks(zipfiles,category_id,title,tags,user_source,intro,rich_intro,image,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
    album = Album.new
    album.uid = @current_uid
    album.nickname = @current_user.nickname
    album.avatar_path = @current_user.logoPic
    album.is_v = @current_user.isVerified
    album.dig_status = @current_user.isVerified ? 1 : 0
    album.human_category_id = @current_user.vCategoryId
    album.title = title
    album.intro = intro
    album.short_intro = intro ? intro[0, 100] : nil
    album.rich_intro = cut_intro(rich_intro)
    album.tags = tags
    album.user_source = user_source.to_i
    album.category_id = category_id
    album.music_category = music_category
    if image.present?
      begin
        img_data = Yajl::Parser.parse(image)
        if img_data and img_data['status']
          pic = img_data['data'][0]['processResult']
          album.cover_path = pic['origin']
        end
      rescue
        #
      end
    end
    album.is_publish = true
    album.is_public = true
    album.is_records_desc = is_records_desc
    album.is_finished = is_finished
    album.status = get_default_status(@current_user)
    album.save

    # 专辑富文本
    cleaned_rich_intro = clean_html(rich_intro)

    setrich = TrackSetRich.stn(album.id).where(track_set_id: album.id).first
    if setrich
      setrich.update_attributes(rich_intro: cleaned_rich_intro)
    else
      TrackSetRich.create(track_set_id: album.id, rich_intro: cleaned_rich_intro)
    end

    # 存专辑下的声音
    response = manage_album_tracks(album, zipfiles, p_transcode_res, default_cover_path, default_cover_exlore_height)

    mqMessage = {
      id: album.id,
      is_new: true,
      created_record_ids: response[:create],
      updated_track_ids: response[:update],
      moved_record_id_old_album_ids: response[:move],
      destroyed_track_ids: response[:destroy],
      share: [sharing_to, share_content],
      user_agent: request.user_agent
    }
    $rabbitmq_channel.queue('album.updated.dj', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain')

    true
  end

  #定时上传专辑
  def delayed_create_album_and_tracks(date,hour,minutes,zipfiles,category_id,title,tags,user_source,intro,rich_intro,image,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)

    year,month,day = date.to_s.split("-")
    datetime = Time.new(year,month,day,hour,minutes).strftime('%Y-%m-%d %H:%M:%S')

    album = DelayedAlbum.new
    album.uid = @current_uid
    album.nickname = @current_user.nickname
    album.avatar_path = @current_user.logoPic
    album.is_v = @current_user.isVerified
    album.dig_status = @current_user.isVerified ? 1 : 0
    album.human_category_id = @current_user.vCategoryId
    album.title = title
    album.intro = intro
    album.short_intro = intro && intro[0, 100]
    album.tags = tags
    album.user_source = user_source
    album.category_id = category_id
    album.music_category  = music_category
    album.is_finished = is_finished
    if image.present?
      begin
        img_data = Yajl::Parser.parse(image)
        if img_data and img_data['status']
          pic = img_data['data'][0]['processResult']
          album.cover_path = pic['origin']
        end
      rescue
        #
      end
    end
    album.is_public = true
    album.is_publish = true
    album.is_records_desc = is_records_desc
    album.publish_at = datetime
    album.status = get_default_status(@current_user)
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

    cleaned_rich_intro = clean_html(rich_intro)

    # 定时发布queue
    $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode({
      delayed_track_ids: delayed_track_ids,
      delayed_album_id: album.id.to_s,
      delayed_publish_at: datetime,
      share: [sharing_to, share_content],
      user_agent: request.user_agent,
      is_records_desc: is_records_desc,
      rich_intro: cleaned_rich_intro
    }), content_type: 'text/plain', persistent: true)

    true
  end

  #更新专辑
  def update_album_and_tracks(album,title,intro,rich_intro,image,category_id,music_category,is_records_desc,is_finished,zipfiles,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,delay_options)
    
    cleaned_rich_intro = clean_html(rich_intro)

    update_album_columns(album,title,intro,rich_intro,cleaned_rich_intro,image,category_id,music_category,is_records_desc,is_finished)
    
    if delay_options
      #将新上传的声音从zipfiles里提取出来
      delayedzipfiles,cleanedzipfiles = [],[]
      zipfiles.each_with_index do |fid,title|
        if ['r','m'].include?(fid[0])
          cleanedzipfiles << [fid,title]
        else
          if (tmp=fid.to_i) > 0
            delayedzipfiles << [tmp,title]
          end
        end
      end
      delayed_create_album_tracks(delay_options[:date],delay_options[:hour],delay_options[:minutes],album,cleaned_rich_intro,delayedzipfiles,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
    else
      cleanedzipfiles = zipfiles
    end

    response = manage_album_tracks(album, cleanedzipfiles, p_transcode_res, default_cover_path, default_cover_exlore_height)

    mqMessage = {
      id: album.id,
      is_new: false,
      created_record_ids: response[:create],
      updated_track_ids: response[:update],
      moved_record_id_old_album_ids: response[:move],
      destroyed_track_ids: response[:destroy],
      share: [sharing_to, share_content],
      user_agent: request.user_agent
    }
    $rabbitmq_channel.queue('album.updated.dj', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain')

    true
  end

  def update_album_columns(album,title,intro,rich_intro,cleaned_rich_intro,image,category_id,music_category,is_records_desc,is_finished)
    tmp_attrs = {
      title: title,
      intro: intro,
      short_intro: intro && intro[0, 100],
      rich_intro: cut_intro(rich_intro),
      category_id: category_id,
      music_category: music_category,
      is_records_desc: is_records_desc,
      is_finished: is_finished
    }

    if image.present?
      begin
      image = Yajl::Parser.parse(image)
      if img_data and img_data['status']
        pic = img_data['data'][0]['processResult']
        tmp_attrs[:cover_path] = pic['origin']
      end
      rescue
        #
      end
    end

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

  #定时上传声音并添加到已有专辑
  def delayed_create_album_tracks(date,hour,minutes,album,cleaned_rich_intro,delayedzipfiles,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)

    return if delayedzipfiles.blank?

    year,month,day = date.to_s.split("-")
    datetime = Time.new(year,month,day,hour,minutes).strftime('%Y-%m-%d %H:%M:%S')

    dalbum = DelayedAlbum.new
    dalbum.uid = album.uid
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
    dalbum.is_public = album.is_public
    dalbum.is_records_desc = album.is_records_desc
    dalbum.is_publish = album.is_publish
    dalbum.publish_at = datetime
    dalbum.status = album.status
    dalbum.rich_intro = album.rich_intro
    dalbum.save
    
    task_count_tag = Time.now.to_i

    # 存专辑下的声音
    track_ids,new_fileid_idx = [],0
    delayedzipfiles.each_with_index do |fid,title|
      
      track_origin = Track.new
      track_origin.uid = @current_uid
      track_origin.status = 2
      track_origin.title = title
      track_origin.save

      track = DelayedTrack.new
      track.task_count_tag = task_count_tag
      d = p_transcode_res['data'][new_fileid_idx]
      track.transcode_state = d['transcode_state']
      track.mp3size = d['paths']['origin_size']
      track.upload_id = d['upload_id']
      track.download_path = d['paths']['aacplus32']
      track.download_size = d['paths']['aacplus32_size']
      track.play_path = d['paths']['origin_path']
      # if d['transcode_state'] == 2
      track.play_path_32 = d['paths']['mp332']
      track.mp3size_32 = d['paths']['mp332_size']
      track.play_path_64 = d['paths']['mp364']
      track.mp3size_64 = d['paths']['mp364_size']
      track.duration = d['duration']
      track.waveform = d['waveform']
      # end
      track.is_crawler = false
      track.upload_source = 2 # 网站上传
      track.uid = album.uid # 源发布者id
      track.nickname = album.nickname # 源发布者昵称
      track.avatar_path = album.avatar_path #源发布者头像
      track.is_v = album.is_v
      track.dig_status = album.dig_status # 发现页可见
      track.human_category_id = album.human_category_id
      track.approved_at = Time.now
      track.track_id = track_origin.id
      track.album_id = album.id # 源专辑id
      track.delayed_album_id = dalbum.id # 临时专辑id
      track.album_title = album.title # 源专辑标题
      track.album_cover_path = album.cover_path
      track.title = newfile[index]
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
      track.fileid = fid
      track.inet_aton_ip = inet_aton(get_client_ip)
      track.status = album.status
      track.save

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
      is_records_desc: album.is_records_desc,
      rich_intro: cleaned_rich_intro
    }
    $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode(mqMessage), content_type: 'text/plain', persistent: true)

    REDIS.incr("#{Settings.delayedpublishcount}.#{Time.new.strftime('%F')}")
  end

  # 处理专辑下的声音
  # fileids对应页面元素： 123: 新上传, m123: (移动的)track_id, r123: (专辑里原有的)record_id
  def manage_album_tracks(album, zipfiles, p_transcode_res, default_cover_path, default_cover_exlore_height, record_ids_to_destroy = [])

    tmp_data = {all_records:[]}

    response = {create:[],update:[],move:[],destroy:[]}

    tracks_count = TrackRecord.stn(album.uid).where(uid: album.uid, album_id: album.id, is_deleted: false, status: 1).count

    destroy_album_tracks(album,record_ids_to_destroy,response[:destroy])

    new_fileid_idx = 0
    zipfiles.each do |fid, title|
      next if fid.blank?
      if fid[0] == 'r'
        next unless (record_id=fid[1..-1].to_i) > 0
        next unless update_album_track(album,record_id,title,tmp_data,response[:update])
      elsif fid[0] == 'm'
        next unless (record_id=fid[1..-1].to_i) > 0
        next unless move_album_track(album,tracks_count,record_id,title,tmp_data,response[:move])
      else
        transcode_data = p_transcode_res['data'][new_fileid_idx]
        new_fileid_idx += 1
        next unless create_album_track(album,tracks_count,title,transcode_data,default_cover_path,default_cover_exlore_height,tmp_data,response[:create])
      end
    end

    # 更新专辑声音排序和最新更新声音
    all_records = tmp_data[:all_records]
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

  def destroy_album_tracks(album,record_ids,register_array)
    record_ids.each do |record_id|
      record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
      if record
        if record.op_type == 1 # 软删声音
          track = Track.stn(record.track_id).where(id: record.track_id).first
          if track
            track.update_attribute(:is_deleted, true)
            register_array << track.id
          end
        end
        record.update_attribute(:is_deleted, true)
      end
    end
    
    true
  end

  def update_album_track(album,record_id,title,tmp_data,register_array)
    record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
    return false unless record

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
        register_array << track.id
      end
    end
    tmp_data[:all_records] << record
    true
  end

  def move_album_track(album,tracks_count,record_id,title,tmp_data,register_array)
    return false if tracks_count >= 200 # 每张专辑上限200首
    
    # 移动的
    record = TrackRecord.stn(album.uid).where(uid: album.uid, id: record_id, is_deleted: false, status: 1).first
    return false unless record

    track = Track.stn(record.track_id).where(uid: album.uid, id: record.track_id, is_deleted: false, status: 1).first
    return false unless track

    old_album_id = track.album_id

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

    tmp_data[:all_records] << record
    register_array << [ record.id, old_album_id ]

    true
  end

  def create_album_track(album,tracks_count,title,transcode_data,default_cover_path,default_cover_exlore_height,tmp_data,register_array)

    return false if tracks_count >= 200 # 每张专辑上限200首
    
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
    track.uid = album.uid # 源发布者id
    track.nickname = @current_user.nickname # 源发布者昵称
    track.avatar_path = @current_user.logoPic #源发布者头像
    track.is_v = @current_user.isVerified
    track.dig_status = @current_user.isVerified ? 1 : 0 # 发现页可见
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

    track_rich = TrackRich.stn(track.id).where(track_id: track.id).first
    unless track_rich
      tsr = TrackSetRich.stn(album.id).where(track_set_id: album.id).first
      TrackRich.create(track_id: track.id, rich_intro: tsr.rich_intro) if tsr
    end
    
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

    tmp_data[:all_records] << record
    register_array << record.id

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

end