module HomeRecommendServiceHelper

  # '精彩推荐' 推荐个人电台
  def get_recommend_user(category_id=nil, page=1, per_page=12)

    data = $recommend_client.hotRadio(category_id, page, per_page)

    users = collect_users(data.ids)

    if ( not_exist_list = data.ids - users.collect{ |u|u.uid } ).length>0
      $backend_client.delHotRadio(category_id, not_exist_list)
    end

    { count: data.count, list: users }
  end

  #'最多粉丝' 推荐个人电台
  def get_recommend_followed_user(category_id=nil, page=1, per_page=12)

    data = $recommend_client.mostFollowedUser(category_id, page, per_page)

    users = collect_users(data.ids)

    if ( not_exist_list = data.ids - users.collect{ |u|u.uid } ).length>0
      $backend_client.delMostFollowedUser(category_id, not_exist_list)
    end

    { count: data.count, list: users }
  end

  #'新晋播主' 推荐个人电台
  def get_recommend_new_user(category_id=nil, page=1, per_page=12)

    data = $recommend_client.newV(category_id, page, per_page)

    users = collect_users(data.ids)

    if ( not_exist_list = data.ids - users.collect{ |u|u.uid } ).length>0
      $backend_client.delNewv(category_id, not_exist_list)
    end

    { count: data.count, list: users }
  end

  #'日榜' 推荐个人电台
  def get_recommend_daily_user(category_id=nil, page=1, per_page=12)

    data = $recommend_client.hotRadioDay(category_id, page, per_page)

    users = collect_users(data.ids)

    if ( not_exist_list = data.ids - users.collect{ |u|u.uid } ).length>0
      $backend_client.delDayHotRadio(category_id, not_exist_list)
    end

    { count: data.count, list: users }
  end

  # '精彩推荐' 推荐声音
  def get_recommend_track(category_id=nil, tag_name=nil, page=1, per_page=12)

    data = $recommend_client.hotSound(category_id, tag_name, page, per_page)

    tracks = collect_tracks(data.ids)

    if ( not_exist_list = data.ids - tracks.collect{ |t|t.track_id } ).length>0
      $backend_client.delHotSound(category_id, tag_name, not_exist_list)
    end

    {count: data.count, list:tracks}
  end

  #'最新上传' 推荐声音
  def get_recommend_recent_track(category_id=nil, tag_name=nil, page=1, per_page=12)

    data = $recommend_client.recentVTrack(category_id, tag_name, page, per_page)

    tracks = collect_tracks(data.ids)

    if ( not_exist_list = data.ids - tracks.collect{ |t|t.track_id } ).length>0
      $backend_client.delRecentVTrack(category_id, tag_name, not_exist_list)
    end
    
    {count: data.count, list:tracks}
  end

  #'最多收藏' 推荐声音
  def get_recommend_favorite_track(category_id=nil, tag_name=nil, page=1, per_page=12)

    data = $recommend_client.mostFavoritSound(category_id, tag_name, page, per_page)

    tracks = collect_tracks(data.ids)

    if ( not_exist_list = data.ids - tracks.collect{ |t|t.track_id } ).length>0
      $backend_client.delMostFavoritSound(category_id, tag_name, not_exist_list)
    end

    {count: data.count, list:tracks}
  end

  #'日榜' 推荐声音
  def get_recommend_daily_track(category_id=nil, tag_name=nil, page=1, per_page=12)

    data = $recommend_client.hotSoundDay(category_id, tag_name, page, per_page)

    tracks = collect_tracks(data.ids)

    if ( not_exist_list = data.ids - tracks.collect{ |t|t.track_id } ).length>0
      $backend_client.delDayHotSound(category_id, tag_name, not_exist_list)
    end

    {count: data.count, list:tracks}
  end

  # 推荐热门专辑
  def get_recommend_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)

    data = $recommend_client.hotAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delHotAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)热门完结专辑
  def get_recommend_finished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)

    data = $recommend_client.hotFinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delHotFinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)热门未完结专辑
  def get_recommend_unfinished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)

    data = $recommend_client.hotUnfinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delHotUnfinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  # 经典专辑
  def get_recommend_classic_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.mostPlayAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delMostPlayAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)经典完结专辑
  def get_recommend_classic_finished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.mostPlayFinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delMostPlayFinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)经典未完结专辑
  def get_recommend_classic_unfinished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.mostPlayUnfinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delMostPlayUnfinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #最新专辑
  def get_recommend_recent_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.recentAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delRecentAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)最新完结专辑
  def get_recommend_recent_finished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.recentFinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delRecentFinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  #(小说分类下)最新未完结专辑
  def get_recommend_recent_unfinished_album(category_id = nil, tag_name = nil, page = 1, per_page = 12)
    
    data = $recommend_client.recentUnfinishedAlbum(category_id, tag_name, page, per_page)

    albums = collect_albums(data.ids)

    if ( not_exist_list = data.ids - albums.collect{ |a|a.id } ).length>0
      $backend_client.delRecentUnfinishedAlbum(category_id, tag_name, not_exist_list)
    end

    return {count: data.count, list: albums}
  end

  def collect_users(arr=[])
    return [] unless arr.size > 0
    profile_users = $profile_client.getMultiUserBasicInfos(arr)
    user_list = []
    arr.each_with_index do |uid,i|
      if u = profile_users[uid]
        user_list << u
      end
    end
    user_list
  end

  def collect_albums(arr=[])
    return [] unless arr.size > 0
    albums = TrackSet.mfetch(arr, true)
    albums = albums.delete_if{|album| album.is_publish==false or album.is_public==false or album.is_deleted==true }
  end

  def collect_tracks(arr=[])
    return [] unless arr.size > 0
    tracks = TrackInRecord.mfetch(arr, true)
    tracks = tracks.delete_if{|track| track.is_publish==false or track.is_public==false or track.is_deleted==true }
  end

  #批量获取单分类多标签下的专辑列表
  def get_multi_recommend_album(category_id=nil, tag_list=[])
    return {} if tag_list.nil? or tag_list.empty?
    category_id = category_id.to_s=="" ? nil : category_id.to_i
    result = {}

    server_data = $recommend_client.hotCategoryAlbum(category_id,tag_list,12)


    server_data.each do |tag,albums|
       album_ids = albums.ids
       result[tag] = TrackSet.mfetch(album_ids, true)
    end
    return result
  end

  def collect_user_hash(arr=[], is_mobile=false)
    if arr.size > 0
      profile_users = $profile_client.getMultiUserBasicInfos(arr)
      user_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, arr)
      user_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, arr)
      user_followings_counts = $counter_client.getByIds(Settings.counter.user.followings, arr)
      latest_tracks = {}
      LatestTrack.where(uid:arr).each do |t|
        latest_tracks[t.uid] = t
      end
    else
      profile_users = {}
      user_tracks_counts = []
      user_followers_counts = []
      user_followings_counts = []
      latest_tracks = {}
    end

    user_hash = {}

    arr.each_with_index do |uid,i|
      u = profile_users[uid]
      if u
        user_hash[uid] = {
          'avatar_path' => u.logoPic,
          'smallLogo' => picture_url('header', u.logoPic, '86', is_mobile),
          'middleLogo' => picture_url('header', u.logoPic, '200', is_mobile),
          'largeLogo' => picture_url('header', u.logoPic, '640', is_mobile),
          'user_cover_path_290' => picture_url('header', u.logoPic, '290', is_mobile),
          'tracks_counts' => user_tracks_counts[i],
          'followers_counts' => user_followers_counts[i],
          'followings_counts' => user_followings_counts[i],
          'lastest_track' => latest_tracks[uid],
          'uid' => u.uid,
          'nickname' => u.nickname,
          'isVerified' => u.isVerified,
          'logoPic' => u.logoPic,
          'personalSignature' => u.personalSignature,
          'personDescribe' => u.personDescribe
        }
      end
    end

    return user_hash
  end

  def collect_sound_hash(arr = [])
    track_hash = {}

    tracks = TrackInRecord.mfetch(arr).select{|track| track}

    tracks.each do |t|
      track_hash[t.track_id] = t
    end

    return track_hash
  end

  #2.0版 发现首页接口
  def get_hot_user_and_sound(category_list)
    
    begin
      resource = $recommend_client.hotRadioAndSound(category_list)
    rescue RuntimeError => e
      resource = nil
      logger.error(e.backtrace.first)
    end

    src_users,result_users = {}, {}
    src_tracks,result_tracks = {}, {}

    if resource
      resource["radio"].each do |k,v|
        src_users[k] = v && v[1..-1]
      end
      flat_uids = src_users.each_value.to_a.flatten.uniq
      user_hash = collect_user_hash(flat_uids)
      src_users.each do |k,v|
        result_users[k] = v.collect{|uid| user_hash[uid] }.compact || []
      end
      
      resource["sound"].each do |k,v|
        src_tracks[k] = v && v[1..-1]
      end
      flat_track_ids = src_tracks.each_value.to_a.flatten.uniq
      sound_hash = collect_sound_hash(flat_track_ids)
      src_tracks.each do |k,v|
        result_tracks[k] = v.collect{|tid| sound_hash[tid] }.compact || []
      end
    end

    return {users:result_users,tracks:result_tracks}

  end

end
