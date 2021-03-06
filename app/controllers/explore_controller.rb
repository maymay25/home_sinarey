class ExploreController < ApplicationController

  set :views, ['explore','application']

  def dispatch(action)
    super(:explore,action)
    method(action).call
  end

  #发现首页
  def index_page
    
    set_no_cache_header

    exadsmar = REDIS.get(Settings.pagedata.exads)
    if exadsmar
      @wall_slide = Marshal.load(exadsmar)
    else
      ads = []
      WebDiscoveryPage.where(is_expired: false).order('position').limit(6).each do |ad|
        if ad.content_type == 2
          id = ad.link_url.split('%2F').last
          track = Track.shard(id).where(id: id, is_public: true, is_deleted: false, status:1).select('id, upload_id, waveform').first
          if track
            track_id = track.id
            track_uploadid = track.upload_id
            track_waveform = track.waveform
          end
        end
        ads << [ ad.link_url, ad.cover_path, ad.content, track_id, track_uploadid, track_waveform ]
      end

      REDIS.set(Settings.pagedata.exads, Marshal.dump(ads))
      @wall_slide = ads
    end

    @wall_user = get_recommend_user(nil,1,  6)[:list]
    server_data = $recommend_client.recentVTrack(nil, nil, 1, 4)
    @wall_new_sound = Track.mfetch(server_data.ids, true)

    p @wall_new_sound

    category_ids = [1,2,3,4,5,6,7,8,9,10,11]
    @category_datas = []
    category_ids.each do |cid|
      category = CATEGORIES[cid]
      next if category.nil?
      @category_datas << {id:category.id,name:category.id,title:category.title}
    end

    datas = get_hot_user_and_sound(category_ids)

    @category_datas.each do |category|
        category[:tags] = get_recommend_category_tag(category[:id]).limit(5)
        category[:users] = datas[:users][category[:id]] || []
        category[:tracks] = datas[:tracks][category[:id]] || []
    end

    editor_recommends = EditorRecommend.where(["start_time < ?",Time.now]).where(["end_time is null or end_time > ?",Time.now]).where(is_expired:0)
    @editor_recommend1 = editor_recommends.where(position:1).first
    @editor_recommend2 = editor_recommends.where(position:2).first
    @editor_recommend3 = editor_recommends.where(position:3).first

    @this_title = "发现 喜马拉雅-听我想听"

    halt erb_js(:index_js) if request.xhr?
    erb :index
  end

  def sound_page

    set_no_cache_header

    @categories = $discover_client.selectWebTrackCategoryAndTag()

    params[:condition] ||= 'daily'

    @this_title = "发现-热门声音 喜马拉雅-听我想听"

    halt erb_js(:sound_page_js) if request.xhr?
    erb :sound_page
  end

  def seo_sound_page

    set_no_cache_header

    @categories = $discover_client.selectWebTrackCategoryAndTag()
    @init_category_name = request.fullpath.gsub("/","").split("?")[0].sub('.ajax','')
    @seo_meta_name = "page"
    @seo_link = @init_category_name
    this_category = Category.where(name: @init_category_name).first
    @init_category_title = this_category.title
    params[:category] = this_category.id

    halt erb_js(:sound_page_js) if request.xhr?
    erb :sound_page
  end

  def seo_new_sound_page

    set_no_cache_header

    @categories = $discover_client.selectWebTrackCategoryAndTag()
    fullpath = request.fullpath

    @init_category_name = fullpath.scan(/\/(.*)\/new/)[0][0]

    @seo_meta_name = "page"
    @seo_link = @init_category_name
    this_category = Category.where(name: @init_category_name).first
    @init_category_title = this_category.title
    params[:category] = this_category.id
    params[:condition] = 'recent'

    halt erb_js(:sound_page_js) if request.xhr?
    erb :sound_page
  end

  def sound_detail

    set_no_cache_header

    category = params[:category].to_i
    category = nil unless category > 0
    tag = (params[:tag].nil? || params[:tag]=="") ? nil : params[:tag]
    page = params[:page].nil? ? 1 : params[:page].to_i
    per_page = params[:per_page].nil? ? 10 : params[:per_page].to_i
    per_page = 100 if per_page>100 #上限100
    condition = params[:condition]

    if condition=="recent"
      server_data = $recommend_client.recentVTrack(category, tag, page, per_page)
    elsif condition=="favorite"
      server_data = $recommend_client.mostFavoritSound(category, tag, page, per_page)
    elsif condition =="hot"
      server_data = $recommend_client.hotSound(category, tag, page, per_page)
    else #daily
      server_data = $recommend_client.hotSoundDay(category, tag, page, per_page)
    end

    track_count,track_ids = server_data.count,server_data.ids

    src_tracks = track_ids.count > 0 ? Track.mfetch(track_ids,true) : []

    src_tracks = src_tracks.delete_if{|t| t.status!=1 or t.is_public==false or t.is_deleted==true }

    #通知删除不存在的声音
    # miss_sum = track_ids.length-src_tracks.length
    # if miss_sum > 0
    #   not_exist_list = track_ids - src_tracks.collect{|t|t.id}
    #   if condition=="zuixinshangchuan"
    #     $backend_client.delRecentVTrack(category, tag, not_exist_list)
    #   elsif condition=="zuiduoshoucang"
    #     $backend_client.delMostFavoritSound(category, tag, not_exist_list)
    #   elsif condition=="jincaituijian"
    #     $backend_client.delHotSound(category, tag, not_exist_list)
    #   else
    #     $backend_client.delDayHotSound(category, tag, not_exist_list)
    #   end
    # end
 
    if src_tracks.length > 0
      src_track_ids = src_tracks.collect{|t| t.id}
      track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, src_track_ids)
      track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, src_track_ids)
      track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, src_track_ids)
      track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, src_track_ids)

      track_uids = src_tracks.map(&:uid)
      @users = track_uids.present? ? $profile_client.getMultiUserBasicInfos(track_uids) : {}
    end

    track_list = []
    src_tracks.each_with_index do |t,i|
      user = @users[t.uid]
      track_list << {
        id:t.id,
        category_id:t.category_id,
        short_intro:t.short_intro,
        nickname:user && user.nickname,
        title:t.title,
        uid:t.uid,
        waterfall_image:t.cover_path && picture_url('track', t.cover_path, '180n'),
        explore_height:t.explore_height,
        upload_id:t.upload_id,
        waveform:t.waveform,
        plays_counts:track_plays_counts[i],
        shares_counts:track_shares_counts[i],
        comments_counts:track_comments_counts[i],
        favorites_counts:track_favorites_counts[i]
      }
    end

    maxPageId = track_count > 0 ? ((track_count-1)/per_page+1) : 1
    render_json({ret:0, maxPageId:maxPageId, list: track_list})
  end

  def user_page

    set_no_cache_header

    @categories = $discover_client.selectWebHumanCategory()

    recommend_users = get_recommend_user(nil, 1, 51)
    @all_users_count = recommend_users[:count]
    @wall_users = recommend_users[:list]
    
    user_detail('init')
    @this_title = "发现-个人电台 喜马拉雅-听我想听"

    halt erb_js(:user_page_js) if request.xhr?
    erb :user_page
  end

  def user_detail(command=nil)

    @page = (params[:page] && params[:page].to_i) || 1
    @per_page = 20
    category = params[:category].to_i
    category = nil unless category>0

    if category
      @category = HumanCategory.where(id: params[:category]).first
    else
      @category = HumanCategory.new(id:0,name:'all',title:'全部')
    end

    params[:condition] ||= 'hot'
    case params[:condition]
    when "fans"
      hot_server_data = get_recommend_followed_user(category, @page, @per_page)
    when "new"
      hot_server_data = get_recommend_new_user(category, @page, @per_page)
    when "daily"
      hot_server_data = get_recommend_daily_user(category, @page, @per_page)
    else
      hot_server_data = get_recommend_user(category, @page, @per_page)
    end

    users = hot_server_data[:list]

    count_info = {}
    uids = users.collect{ |u| u.uid }
    @tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, uids)
    @followers_counts = $counter_client.getByIds(Settings.counter.user.followers, uids)

    @users         = users
    @users_count   = hot_server_data[:count]

    if command!="init"
      set_no_cache_header
      halt render_to_string(partial: :'_user_detail')
    end
  end

  def album_page
    
    set_no_cache_header

    @categories = $discover_client.selectWebAlbumCategoryAndTag()
    album_detail('init')
    @this_title = "发现-热门专辑 喜马拉雅-听我想听"

    halt erb_js(:album_page_js) if request.xhr?
    erb :album_page
  end

  #condition: hot.热门(默认) recent.最近更新 classic.经典
  #status 0 -> 全部，1->完结，2->连载中
  def album_detail(command=nil)

    category = params[:category].to_i
    category = nil unless category > 0
    tag = (params[:tag].nil? || params[:tag]=="") ? nil : params[:tag]
    @page = params[:page].nil? ? 1 : params[:page].to_i
    @per_page = 12
    status = params[:status].to_i

    args = [category,tag,@page,@per_page]

    params[:condition] ||= 'hot'

    status_categories = [3,9,14]
    cache_json = case params[:condition]
    when 'recent'
      if status_categories.include?(category) and [1,2].include?(status)
        case status
        when 1
          get_recommend_recent_finished_album(*args)
        when 2
          get_recommend_recent_unfinished_album(*args)
        end
      else
        get_recommend_recent_album(*args)
      end
    when 'classic'
      if status_categories.include?(category) and [1,2].include?(status)
        case status
        when 1
          get_recommend_classic_finished_album(*args)
        when 2
          get_recommend_classic_unfinished_album(*args)
        end
      else
        get_recommend_classic_album(*args)
      end
    else #hot
      if status_categories.include?(category) and [1,2].include?(status)
        case status
        when 1
          get_recommend_finished_album(*args)
        when 2
          get_recommend_unfinished_album(*args)
        end
      else
        get_recommend_album(*args)
      end
    end

    @albums_count = cache_json[:count]
    @albums = cache_json[:list]

    album_ids = @albums.collect{ |a| a.id }
    if album_ids.count > 0
      @album_plays_counts = $counter_client.getByIds(Settings.counter.album.plays, album_ids)
    else
      @album_plays_counts = []
    end

    if command!="init"
      set_no_cache_header
      halt render_to_string(partial: :'_album_detail')
    end
  end

  #批量获取用户的关注状态
  def get_follow_status

    set_no_cache_header

    return render_json({res: true, result:{}}) if params[:uids].blank?
    return render_json({res: true, result:{}}) if @current_uid.nil?
    hash,fuids = {},[]
    params[:uids].split(',').each do |uid|
      next unless (uid=uid.to_i) > 0
      hash[uid] = {}
      fuids << uid
    end
    following = Following.shard(@current_uid)
    followings = following.select('following_uid,is_mutual').where(uid: @current_uid, following_uid:fuids)
    followings.each do |follow|
      hash[follow.following_uid] = {is_follow:true,be_followed:follow.is_mutual==true}
    end
    render_json({res: true, result: hash})
  end


private

  def get_recommend_category_tag(category_id,type="track")
    category_id = category_id.to_i
    category_id = nil unless category_id > 0
    if type=="album"
      if category_id
        filter = {category_id: category_id}
        @recommend_category_tag = HumanRecommendAlbumCategoryTag.where(filter).order("position asc")
      else
        @recommend_category_tag = HumanRecommendAlbumTag.order("position asc")
      end
    else
      if category_id
        filter = {category_id: category_id}
        @recommend_category_tag = HumanRecommendCategoryTag.where(filter).order("position asc")
      else
        @recommend_category_tag = HumanRecommendCategoryTag.where('category_id = 0').order("position asc")
      end
    end

    return @recommend_category_tag
  end

end
