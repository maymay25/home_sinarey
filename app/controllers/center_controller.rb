class CenterController < ApplicationController
  include CenterHelper

  set :views, ['center','application']

  def dispatch(action)
    super(:center,action)
    method(action).call
  end

  ### 个人中心 -- 首页timeline
  def index_page

    redirect_to_root

    if params[:nickname]
      users = $profile_client.getProfileByNickname(params[:nickname])
      halt_404 if users.empty?
      uid = users.first.uid
      @u = get_profile_user_basic_info(uid)
    else
      @u = get_profile_user_basic_info(params[:uid].to_i)
    end

    halt_404 if @u.nil? or @u.isLoginBan

    is_current_user = @current_uid==@u.uid
    fullpath_include_profile = request.fullpath.split("?")[0].include?('profile')

    redirect xhr_redirect_link("/#{@u.uid}/profile") if is_current_user and !fullpath_include_profile

    redirect xhr_redirect_link("/#{@u.uid}") if !is_current_user and fullpath_include_profile

    init_index_page

    halt erb_js(:timeline_js) if request.xhr?
    erb :timeline
  end

  def get_timeline_list

    set_no_cache_header

    @timeline_list = init_timeline_data

    render_to_string(partial: :_timeline_list)
  end

  ### feed
  def get_feeds

    halt_404 unless request.xhr?

    halt_400 unless @current_uid

    set_no_cache_header

    if @current_uid.nil? or (@current_uid != params[:uid].to_i && @current_user.nickname != params[:nickname])
      halt_js 'window.location.href="/"'
    end

    @categories = {}.tap{ |h| Category.order("order_num asc").each{ |c| h[c.id] = [c.name, c.title] } }

    if params[:groupID].present? && params[:groupID] != '0'
      uid_gid = "#{@current_uid}_#{params[:groupID]}"
    else
      uid_gid = @current_uid.to_s
    end

    if params[:pageSize]
      @pageSize = params[:pageSize].to_i
    else
      @pageSize = 10
    end

    begin
      @feeds = $feed_client.getWebSoundRange(uid_gid, 0, @pageSize)
    rescue Errno::ECONNREFUSED, Thrift::ApplicationException
      halt_500
    end

    if @feeds
      @feed_uids = []
      feedData = @feeds.datas
      hash = Hash.new
      if feedData && feedData.size > 0
        feedData.each do |f|
          # 转发
          if f.type && f.type=='fts'
            @feed_uids << f.toUid
          end
          @feed_uids << f.uid
        end
        @feed_uids.uniq!
        hash[:timeLine] = feedData[-1].timeLine
      # elsif @feeds.timeLine.nil?
      #   hash[:timeLine] = params[:timeLine]
      end
      hash[:delNum] = @feeds.delNum
      hash[:unreadNum] = @feeds.unreadNum
      hash[:pageSize] = @feeds.pageSize
      hash[:currentSize] = @feeds.currentSize
      hash[:totalSize] = @feeds.totalSize
      @feeds_json = oj_dump(hash)
    end

    set_my_counts
    
    @this_title = '喜马拉雅-听我想听'

    halt erb_js(:'my/feeds_js')
  end

  def get_more_feeds

    halt_404 unless request.xhr?

    halt_400 unless @current_uid

    set_no_cache_header

    feedType = params[:feedType] || 'sound'

    if params[:groupID].present? && params[:groupID] != '0'
      uid_gid = "#{@current_uid}_#{params[:groupID]}"
    else
      uid_gid = @current_uid.to_s
    end

    if params[:pageSize]
      @pageSize = params[:pageSize].to_i
    else
      @pageSize = 10
    end
    if params[:page]
      @page = params[:page].to_i
    else
      @page = 1
    end

    if params[:moreCount]
      @moreCount = params[:moreCount].to_i
    else
      @moreCount = 0
    end
    
    if @moreCount == 0
      offset = (@page - 1) * @pageSize * 3
      if feedType == 'sound'
        begin
          @feeds = $feed_client.getWebSoundRange(uid_gid, offset, @pageSize)

        rescue Errno::ECONNREFUSED
          render_500
          return
        end
      else
        begin
          @feeds = $feed_client.getWebEventRange(uid_gid, offset, @pageSize)

        rescue Errno::ECONNREFUSED
          render_500
          return
        end
      end
    else
      type = -1
      if feedType == 'sound'
        begin
          @feeds = $feed_client.getWebSoundTimeline(uid_gid, params[:timeLine].to_f, @pageSize, type)

        rescue Errno::ECONNREFUSED
          render_500
          return
        end
      else
        begin
          @feeds = $feed_client.getWebEventTimeline(uid_gid, params[:timeLine].to_f, @pageSize, type)
        rescue Errno::ECONNREFUSED
          render_500
          return
        end
      end
    end

    @categories = {}.tap{ |h| Category.order("order_num asc").each{ |c| h[c.id] = [c.name, c.title] } }
    
    if @feeds
      @feed_uids = []
      feedData = @feeds.datas
      hash = Hash.new
      if feedData && feedData.size > 0
        feedData.each do |f|
          # 转发
          if f.type && f.type=='fts'
            @feed_uids << f.toUid
          end
          @feed_uids << f.uid
        end
        @feed_uids.uniq!
        hash[:timeLine] = feedData[-1].timeLine
      else 
        hash[:timeLine] = params[:timeLine]
      end
      hash[:delNum] = @feeds.delNum
      hash[:unreadNum] = @feeds.unreadNum
      hash[:pageSize] = @feeds.pageSize
      hash[:currentSize] = @feeds.currentSize
      hash[:totalSize] = @feeds.totalSize
      @feeds_json = oj_dump(hash)
    end

    halt erb_js(:'my/more_feeds_js')
  end

  #删除用户feed
  def do_del_feed

    halt_400 unless @current_uid

    # 查询用户的所有分组信息
    groups = FollowingGroup.shard(@current_uid).where(uid: @current_uid)
    # 删除指定feed
    res = $feed_client.deleteFeed(@current_uid.to_s, params[:feed_id], params[:feedType], groups.map{|g| g['id'].to_s})

    render_json((res ? '200' : '500'))
  end
  
  #获取用户未读数
  def get_no_read_feed_num

    halt_404 unless @current_uid

    set_no_cache_header

    if params[:groupID].present? and params[:groupID] != '0'
      uid_gid = "#{@current_uid}_#{params[:groupID]}"
    else
      uid_gid = @current_uid.to_s
    end
    unread = $feed_client.getWebUnread(uid_gid)
    render_json({groupID: unread.groupId,eventNum: unread.event,soundNum: unread.sound})
  rescue Thrift::ApplicationException => e
    app_logger.error("$feed_client.getWebUnread(#{uid_gid.inspect})")
    raise e
  end

  ### 声音列表页
  def sound_page

    redirect_to_root

    if @current_uid and @current_uid == params[:uid].to_i
      init_my_sound_page
      halt erb_js(:'my/sound_js') if request.xhr?
      halt_404
    end

    @u = get_profile_user_basic_info(params[:uid].to_i)
    halt_404 if @u.nil? or @u.isLoginBan

    init_his_sound_page
    halt erb_js(:sound_page_js) if request.xhr?
    erb :sound_page
  end

  ### 专辑列表页
  def album_page

    redirect_to_root

    if @current_uid and @current_uid == params[:uid].to_i
      init_my_album_page
      halt erb_js(:'my/album_js') if request.xhr?
      halt_404
    end

    @u = get_profile_user_basic_info(params[:uid].to_i)
    halt_404 if @u.nil? or @u.isLoginBan
    
    init_his_album_page
    halt erb_js(:album_page_js) if request.xhr?
    erb :album_page
  end

  ### 关注列表页
  def follow_page

    redirect_to_root

    if @current_uid and @current_uid == params[:uid].to_i
      init_my_follow_page
      halt erb_js(:'my/follow_js') if request.xhr?
      halt_404
    end

    @u = get_profile_user_basic_info(params[:uid].to_i)
    halt_404 if @u.nil? or @u.isLoginBan

    init_his_follow_page
    halt erb_js(:follow_page_js) if request.xhr?
    erb :follow_page
  end

  ### 粉丝列表页
  def fans_page

    redirect_to_root

    if @current_uid and @current_uid == params[:uid].to_i
      init_my_fans_page
      halt erb_js(:'my/fans_js') if request.xhr?
      halt_404
    end

    @u = get_profile_user_basic_info(params[:uid].to_i)
    halt_404 if @u.nil? or @u.isLoginBan

    init_his_fans_page
    halt erb_js(:fans_page_js) if request.xhr?
    erb :fans_page
  end

  ### 喜欢的声音列表页
  def favorites_page

    redirect_to_root

    if @current_uid and @current_uid == params[:uid].to_i
      init_my_favorites_page
      halt erb_js(:'my/favorites_js') if request.xhr?
      halt_404
    end

    @u = get_profile_user_basic_info(params[:uid].to_i)
    halt_404 if @u.nil? or @u.isLoginBan

    init_his_favorites_page
    halt erb_js(:favorites_page_js) if request.xhr?
    erb :favorites_page
  end

  ### 听过的声音列表页
  def listened_page

    redirect_to_root

    halt_404 unless @current_uid and @current_uid == params[:uid].to_i

    oj = REDIS.get("listened#{@current_uid}")
    if oj
      begin
        @listeneds = Oj.load(oj)
      rescue ArgumentError => e
        @listeneds = []
      end
    else
      @listeneds = []
    end
    track_ids = @listeneds.map{|listened_at, track_id| track_id}
    @tracks = Track.mfetch(track_ids,true)
    
    if @tracks.size > 0
      
      track_ids = @tracks.collect{|t| t.id }
      @users = $profile_client.getMultiUserBasicInfos(@tracks.map{|track| track.uid})
      @track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
      @track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, track_ids)

      @is_favorited = {}
      if @current_uid
        favorite_status = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids)
        favorite_status.each do |f|
          @is_favorited[f.track_id] = true
        end
      end

    end

    favorites = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids).select("track_id").collect {|f| f.track_id}
    @categories = {}.tap{ |h| Category.order("order_num asc").each{ |c| h[c.id] = [c.name, c.title] } }
    @this_title = "我听过的声音 喜马拉雅-听我想听"

    halt erb_js(:'my/listened_js') if request.xhr?
    halt_404
  end

  ### 定时发布任务列表页
  def publish_page

    redirect_to_root

    halt_404 unless @current_uid and @current_uid == params[:uid].to_i

    @public_tasks = DelayedTrack.where(:uid => @current_uid,:is_deleted => false).select(:task_count_tag).uniq.size
    
    cond1 = {uid: @current_uid, status: [0, 1], is_deleted: false}
    if params[:user_source]
      cond1[:user_source] = params[:user_source]
    end

    cond1[:is_public] = true
    cond1[:album_id] = nil

    order = "publish_at desc"
    orderhash = []

    @track_records = DelayedTrack.where(cond1).where(delayed_album_id:nil).order(order)

    @albums_records = DelayedAlbum.where(uid: @current_uid, status: [0, 1], is_deleted: false).order(order)

    all_delayed_tasks = {}
    all_time_arr = []

    @track_records.each do |track|
      time_key = track.created_at.to_i
      all_time_arr << time_key
      all_delayed_tasks[time_key] = {type:'sound',data:track}
    end

    @albums_records.each do |album|
      time_key = album.created_at.to_i
      all_time_arr << time_key
      all_delayed_tasks[time_key] = {type:'album',data:album}
    end

    @results = all_time_arr.sort{|x,y| y <=> x}.collect{|key| all_delayed_tasks[key] }

    halt erb_js(:'my/publish_js') if request.xhr?
    halt_404
  end

  ##json 声音列表
  def get_sound_list

    set_no_cache_header

    page = (tmp=params[:page].to_i)>0 ? tmp : 1
    per_page = (tmp=params[:per_page].to_i)>0 ? tmp : Settings.per_page.my_tracks 

    all_track_records = TrackRecord.shard(params[:uid]).where(uid: params[:uid], status: 1, is_deleted: false)
    response = {}
    response[:count] = all_track_records.count
    response[:page] = page
    response[:per_page] = per_page
    response[:list] = all_track_records.order("id desc").offset((page-1)*per_page).limit(per_page).collect do |r|
      {
        title: r.title,
        play_path_64: file_url(r.play_path_64),
        cover_path_142: picture_url('track', r.cover_path, '180'),
        duration: r.duration,
        id: r.track_id
      }
    end
    render_json(response)
  end

  # 显示名片
  def get_show_card

    set_no_cache_header

    halt render_json({}) unless params[:uid]

    if params[:uid][0] == 'n'
      users = $profile_client.getProfileByNickname(params[:uid][1..-1])
      halt render_json({}) if users.empty? 
      user = users.first
    else
      user = get_profile_user_basic_info(params[:uid].to_i)
    end

    halt render_json({}) if user.nil? or user.isLoginBan

    tracks_count, followings_count, followers_count = $counter_client.getByNames([
        Settings.counter.user.tracks,
        Settings.counter.user.followings,
        Settings.counter.user.followers
      ], user.uid)

      if @current_uid
        following = Following.shard(@current_uid).where(uid: @current_uid, following_uid: user.uid).first
        is_follow = following.present?
        be_followed = is_follow && following.is_mutual==true
      else
        is_follow = false
        be_followed = false
      end

    card = {
    is_not_following:!is_follow,
    be_followed:be_followed,
      tracks_count: tracks_count,
      followings_count: followings_count,
      followers_count: followers_count,
      avatar_url_60: picture_url('header', user.logoPic, '60'),
      personalSignature: CGI::escapeHTML(user.personalSignature || ''),
      uid: user.uid,
      nickname: user.nickname,
      isVerified: user.isVerified,
      logoPic: user.logoPic,
      province: user.province,
      city: user.city,
      town: user.town,
      ptitle: user.ptitle
    }

    render_json(card)
  end

  #声音ids
  def get_sound_ids

    set_no_cache_header

    @track_records = TrackRecord.shard(params[:uid]).where(uid: params[:uid], transcode_state: 2, is_deleted: false, status: 1).order('id desc').page(params[:page]).per(Settings.per_page.my_tracks)
    @sound_ids = @track_records.collect{|r| r.track_id } || []

    render_json(@sound_ids)
  end

  #获取消息数量
  def get_msg_notice

    set_no_cache_header

    halt render_json({res: nil, msg: print_message(:params_missing, "current uid")}) unless @current_uid

    arr = $counter_client.getByNames([
        Settings.counter.user.new_message,
        Settings.counter.user.new_notice,
        Settings.counter.user.new_comment,
        Settings.counter.user.new_quan,
        Settings.counter.user.new_follower,
        Settings.counter.user.new_like
      ], @current_uid)

    notices = {
      new_message: arr[0],
      new_notice: arr[1],
      new_comment: arr[2],
      new_quan: arr[3],
      new_follower: arr[4],
      new_like: arr[5]
    }

    render_json({res: notices, msg: print_message(:success)})
  end

  #清楚消息数量
  def do_clear_msg_notices

    halt render_json({res: nil, msg: print_message(:params_missing, "current uid")}) unless @current_uid

    if params[:category]
      $counter_client.set(Settings.counter.user[params[:category]], @current_uid, 0)
    else
      $counter_client.set(Settings.counter.user.new_message, @current_uid, 0)
      $counter_client.set(Settings.counter.user.new_notice, @current_uid, 0)
      $counter_client.set(Settings.counter.user.new_comment, @current_uid, 0)
      $counter_client.set(Settings.counter.user.new_quan, @current_uid, 0)
      $counter_client.set(Settings.counter.user.new_follower, @current_uid, 0)
      $counter_client.set(Settings.counter.user.new_like, @current_uid, 0)
    end

    render_json({res: true, msg: print_message(:success)})
  end

  #圈人提示
  def get_quan_suggest
    halt_400 unless @current_uid
      
    nicknames = Following.shard(@current_uid).where('following_nickname like ? and uid = ?', "%#{params[:q]}%", @current_uid).select('following_nickname').limit(10).map{|f| f.following_nickname}
    halt '' unless nicknames.size > 0

    halt nicknames.join(',')
  end

  #举报
  def do_create_report

    halt_400 unless @current_uid

    #整理参数
    tmp = {
      report_id:params[:report_id],
      content:params[:content],
      uid:params[:uid],
      nickname:params[:nickname],
      to_uid:params[:to_uid],
      to_nickname:params[:to_nickname],
      content_id:params[:content_id],
      content_title:params[:content_title],
      fujian_path:params[:fujian_path],
      content_type:params[:content_type],
      track_id:params[:track_id],
      album_id:params[:album_id],
      comment_id:params[:comment_id]
    }

    report = ReportInformation.new(tmp)
    validate = report.report_id and report.uid and report.content_title and report.content_type and (report.track_id or report.album_id)
    if validate and report.save
      # 举报的人收到一条系统通知
      xima = get_profile_user_basic_info(1)
      Inbox.create( uid: xima.uid,
            nickname: xima.nickname,
            avatar_path: xima.logoPic,
            to_uid: @current_uid,
            to_nickname: @current_user.nickname,
            to_avatar_path: @current_user.logoPic,
            message_type: 5,
            content: "您好，您的举报信息我们已经收到。非常感谢您对我们工作的支持。" )

      $counter_client.incr(Settings.counter.user.new_notice, @current_uid, 1)

      halt render_json({ result: "success" })
    else
      halt render_json({ result: "failure" })
    end
  end

  #podcast 服务
  def podcast_page

    redirect '/' if @current_uid.nil? or !@current_user.isVerified

    page = ( tmp=params[:page].to_i ) > 0 ? tmp : 1

    all_aplts = AlbumPodApplication.where(uid:@current_uid).order('id desc')

    all_aplts_count = all_aplts.count
    redirect '/podcast/apply' if all_aplts_count==0

    @next_page = (all_aplts_count>page*10) && (page+1)
    @aplts = all_aplts.offset((page-1)*10).limit(10)
    if @aplts.length>0
      albums_ids = @aplts.collect{|a|a.album_id}
      albums = Album.shard(@current_uid).where(uid: @current_uid, status: [0, 1], is_deleted: false,id:albums_ids)
      @albums_hash = {}
      albums.each do |album|
        @albums_hash[album.id] = album
      end
    end

    erb :podcast_record
  end

  #podcast 申请
  def podcast_apply_page

    redirect '/podcast/record' if @current_uid.nil? or !@current_user.isVerified
    get_podcast_apply_albums(init:true)

    @categories = get_podcast_categories

    erb :podcast_apply
  end

  #podcast 专辑列表
  def get_podcast_apply_albums(options={})

    halt render_json({next_page: false, html:''}) if !options[:init] and @current_uid.nil?
    page = ( tmp=params[:page].to_i ) > 0 ? tmp : 1
    all_albums = Album.shard(@current_uid).where(uid: @current_uid, status: [0, 1], is_deleted: false).order('last_uptrack_at desc')
    @next_page = (all_albums.count>page*10) && (page+1)
    @albums = all_albums.offset((page-1)*10).limit(10)

    html = render_to_string(partial: :_podcast_apply_albums, locals: {albums:@albums})
    render_json({next_page: @next_page, html:html}) if !options[:init]
  end

  #podcast 创建action
  def do_create_podcast

    halt render_json({res: false, msg:'请先登陆'}) if @current_uid.nil? or !@current_user.isVerified

    halt render_json({res: false, msg:'加V用户才能使用该功能'}) if !@current_user.isVerified

    album_id = params[:album_id].to_i
    halt render_json({res: false, msg:'请选择专辑'}) if album_id<=0

    halt render_json({res: false, msg:'请选择图片'}) if params[:faceimage].blank?

    #查看是否已经提交过相同专辑的申请
    already = AlbumPodApplication.where(uid:@current_uid,album_id:album_id,status:[0,1]).first
    if already
      case already.status
      when 0
        halt render_json({res: false, msg:'所选专辑的podcast申请已经在审核中'})
      when 1
        halt render_json({res: false, msg:'所选专辑的podcast申请已经通过，请不要重复申请'})
      end
    end

    explicit = params[:explicit]=='yes' ? 'yes' : 'no'

    #检查分类是否正确
    pod_categories = Array.wrap(params[:pod_category])
    pod_sub_categories = Array.wrap(params[:pod_sub_category])

    all_categories = get_podcast_categories
    whitelist_categories = all_categories.keys

    result_categories = []
    pod_categories.each_with_index do |category,index|
      next unless whitelist_categories.include? category
      sub_category = pod_sub_categories[index]
      whitelist_sub_categories = all_categories[category]['sub_category'].keys
      if whitelist_sub_categories.empty?
        result_categories << {category:category,sub_category:''}
      else
        next unless whitelist_sub_categories.include? sub_category
        result_categories << {category:category,sub_category:sub_category}
      end
    end
    halt render_json({res: false, msg:'请选择分类'}) if result_categories.empty?

    #检查一下字段
    tmp = {
      album_id:album_id,
      explicit:explicit,
      pod_cover_path:params[:faceimage],
      uid:@current_uid
    }

    cindex = 0
    3.times do |n|
      data = result_categories[n]
      next if data.nil?
      cindex += 1
      tmp["pod_category#{cindex}".to_sym] = data[:category]
      tmp["pod_sub_category#{cindex}".to_sym] = data[:sub_category]
    end

    aplt = AlbumPodApplication.new(tmp)
    if aplt.save

      #AlbumPod 和 AlbumPodcat 要差对应的记录

      halt render_json({res: true,aplt_id:aplt.id})
    else
      halt render_json({res: false, msg: '创建失败'})
    end
  end

  #申请结果 id
  def podcast_apply_result_page

    redirect '/podcast/record' if @current_uid.nil? or !@current_user.isVerified

    @aplt = AlbumPodApplication.where(id:params[:id],uid:@current_uid).first
    redirect '/podcast/record' if @aplt.nil?

    @album = TrackSet.shard(@aplt.album_id).where(uid: @current_uid, id: @aplt.album_id, status: [0, 1], is_deleted: false).first
    redirect '/podcast/record' if @album.nil?

    erb :podcast_apply_result
  end

  private

  def init_index_page

    set_his_counts(@u.uid)
    begin
      @timeline_calendar = get_timeline_meta(@u.uid,Time.at(@u.createdTime/1000) )
    rescue Errno::ECONNREFUSED
      halt_500
      return
    end

    track_tmp = LatestTrack.where(uid: @u.uid).first
    @latest_track = track_tmp && Track.fetch(track_tmp.track_id)

    album_tmp = LatestAlbum.where(uid: @u.uid).first
    @latest_album = album_tmp && TrackSet.fetch(album_tmp.album_id)

    @latest_favorite = LatestFavorite.where(uid: @u.uid).first


    all_followers = Follower.shard(@u.uid).where(following_uid: @u.uid).select('id, uid').order('id desc')
    @followers = all_followers.limit(14)

    follower_uids = @followers.collect{|f| f.uid}
    if follower_uids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(follower_uids)
    else
      @users = {}
    end

    if @timeline_calendar
      if init_date = @timeline_calendar[:list] && @timeline_calendar[:list][0]
        params[:year] = init_date[:year]
        params[:month] = init_date[:month]
        params[:uid] = @u.uid
        params[:page] = 1
        params[:per_page] = 30
      end
    end

    if @current_uid==@u.uid
      @this_title = "我的主页 喜马拉雅-听我想听"
    else
      @this_title = "#{@u.nickname}的主页 喜马拉雅-听我想听"
    end
  end

  def init_my_sound_page
    query = ["title like ?", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件

    cond1 = {uid: @current_uid, status: [0, 1], is_deleted: false}
    if params[:user_source]
      cond1[:user_source] = params[:user_source]
      cond1[:op_type] = TrackRecordTemp::OP_TYPE[:UPLOAD]
    end
    cond1[:op_type] = params[:op_type].to_i if params[:op_type]
    cond1[:is_public] = params[:is_public].to_s!="0" if params[:is_public]

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.my_tracks

    order = (["id desc" , "id asc"].include?(params[:order]) && params[:order]) || "id desc"
    all_track_records = TrackRecord.shard(@current_uid).where(cond1).where(query)
    @track_records_count = all_track_records.count
    @track_records = all_track_records.order(order).offset((@page-1)*@per_page).limit(@per_page)
    
    if @track_records.length > 0

      track_ids = @track_records.collect{|r| r.track_id }.compact.uniq

      track_uids = @track_records.collect{|r| r.track_uid }.compact.uniq
      @users = track_uids.present? ? $profile_client.getMultiUserBasicInfos(track_uids) : {}

      @albums = {}
      album_ids = @track_records.collect{|r| r.album_id }.compact.uniq
      ori_albums = album_ids.present? ? TrackSet.mfetch(album_ids,true) : []
      ori_albums.each do |album|
        @albums[album.id] = album
      end

      @track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
      @track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, track_ids)

      @is_favorited = {}
      if @current_uid
        favorite_status = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids)
        favorite_status.each do |f|
          @is_favorited[f.track_id] = true
        end
      end
    end

    @my_newest_albums =  Album.shard(@current_uid).where(uid: @current_uid, status: [0, 1], is_deleted: false).order('id desc').limit(6)
    album_ids = @my_newest_albums.collect{ |a| a.id }
    if album_ids.count > 0
      @album_tracks_count = $counter_client.getByIds(Settings.counter.album.tracks, album_ids)
    else
      @album_tracks_count = []
    end
    @this_title = "我的声音 喜马拉雅-听我想听"
  end

  def init_his_sound_page
    cond1 = {uid: @u.uid, status: 1, is_deleted: false}
    cond1[:is_public] = true if @u.uid != @current_uid
    query = ["title like ?", "%#{params[:q]}%"] if params[:q].present?
    order = (["id desc" , "id asc"].include?(params[:order]) && params[:order]) || "id desc"

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.my_tracks

    all_track_records = TrackRecord.shard(@u.uid).where(cond1).where(query)
    @track_records_count = all_track_records.count

    @track_records = all_track_records.order(order).offset((@page-1)*@per_page).limit(@per_page)
    
    if @track_records.length > 0

      track_ids = @track_records.map(&:track_id).compact.uniq
      track_uids = @track_records.map(&:track_uid).compact.uniq
      @users = track_uids.present? ? $profile_client.getMultiUserBasicInfos(track_uids) : {}

      @albums = {}
      album_ids = @track_records.collect{|r| r.album_id }.compact.uniq

      ori_albums = album_ids.present? ? TrackSet.mfetch(album_ids,true) : []

      ori_albums.each do |album|
        @albums[album.id] = album
      end

      @track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
      @track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, track_ids)

      @is_favorited = {}
      if @current_uid
        favorite_status = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids)
        favorite_status.each do |f|
          @is_favorited[f.track_id] = true
        end
      end
    end

    @his_newest_albums =  Album.shard(@u.uid).where(uid: @u.uid, status: 1, is_deleted: false).order('id desc').limit(6)

    album_ids = @his_newest_albums.collect{ |a| a.id }
    if album_ids.count > 0
      @album_tracks_count = $counter_client.getByIds(Settings.counter.album.tracks, album_ids)
    else
      @album_tracks_count = []
    end

    check_follow_status(@u.uid)

    @this_title = "#{@u.nickname}的声音 喜马拉雅-听我想听"
  end

  def init_my_album_page
    query = ["title like ?", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件
    
    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.my_albums

    order = (["last_uptrack_at desc" , "last_uptrack_at asc"].include?(params[:order]) && params[:order]) || "last_uptrack_at desc"
    all_albums = Album.shard(@current_uid).where(uid: @current_uid, status: [0, 1], is_deleted: false).where(query)
    @albums_count = all_albums.count
    @albums = all_albums.order(order).offset((@page-1)*@per_page).limit(@per_page)

    album_ids = @albums.collect{ |a| a.id }
    if album_ids.count > 0
      @album_tracks_counts = $counter_client.getByIds(Settings.counter.album.tracks, album_ids)
    else
      @album_tracks_counts = []
    end
    @this_title = "我的专辑 喜马拉雅-听我想听"
  end

  def init_his_album_page
    query = ["title like ?", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.my_albums

    order = (["last_uptrack_at desc" , "last_uptrack_at asc"].include?(params[:order]) && params[:order]) || "last_uptrack_at desc"
    all_albums = Album.shard(@u.uid).where(uid: @u.uid, status: 1, is_deleted: false).where(query)
    @albums_count = all_albums.count
    @albums = all_albums.order(order).offset((@page-1)*@per_page).limit(@per_page)

    album_ids = @albums.collect{ |a| a.id }
    if album_ids.count > 0
      @album_tracks_counts = $counter_client.getByIds(Settings.counter.album.tracks, album_ids)
    else
      @album_tracks_counts = []
    end

    check_follow_status(@u.uid)

    @this_title = "#{@u.nickname}的专辑 喜马拉雅-听我想听"
  end

  def init_my_follow_page
    query = ["following_nickname like ?", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件
    
    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.follows

    @fgs = FollowingGroup.shard(@current_uid).where(uid: @current_uid)

    all_follows = Following.shard(@current_uid).where(uid: @current_uid).where(query)
    
    if params[:following_group_id]
      if params[:following_group_id].strip.empty? # 未分组
        fids = Followingx2Group.shard(@current_uid).where(uid: @current_uid).select('following_id').collect{|fx2g| fx2g.following_id }
        if fids.size > 0
          all_follows = all_follows.where('is_auto_push = 0 and id not in (?)', fids)
        else
          all_follows = all_follows.where('is_auto_push = 0')
        end
      elsif params[:following_group_id].to_i == -1 # 必听
        all_follows = all_follows.where(is_auto_push: true)
      else # 某分组
        fids = Followingx2Group.shard(@current_uid).where(uid: @current_uid, following_group_id: params[:following_group_id]).collect{|fx2g| fx2g.following_id}
        all_follows = all_follows.where(id: fids)
      end
    end

    all_follows = all_follows.where(is_mutual: true) if params[:is_mutual] # 相互关注
    @follows_count = all_follows.count
    @follows = all_follows.order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    following_ids,following_uids = [],[]
    @follows.each do |f|
      following_ids << f.id
      following_uids << f.following_uid
    end

    if @follows.size > 0
      @users = $profile_client.getMultiUserBasicInfos(following_uids.collect{|uid| uid })
      @following_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, following_uids)
      @following_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, following_uids)
      @follow_status = {}
      @follows.each do |follow|
        @follow_status[follow.following_uid] = [true,follow.is_mutual]
      end

      cache_group_hash = {}
      @follow_group_ids_hash = {}
      x2_groups = Followingx2Group.shard(@current_uid).where(uid: @current_uid, following_id: following_ids).select('following_id,following_group_id')
      x2_groups.each do |x2_group|
        cache_group_hash[x2_group.following_group_id] ||= 1
        (@follow_group_ids_hash[x2_group.following_id] ||= []) << x2_group.following_group_id
      end

      @fgs = {}
      all_group_ids = cache_group_hash.keys
      FollowingGroup.shard(@current_uid).where(uid: @current_uid,id:all_group_ids).each do |fg|
        @fgs[fg.id] = fg
      end
    end
    @this_title = "我关注的人 喜马拉雅-听我想听"
  end

  def init_his_follow_page
    @follows_count = Following.shard(@u.uid).where(uid: @u.uid).count

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @page=1 if @page > 10 #只显示前10页列表,之后的页码显示第一页列表
    @per_page = Settings.per_page.follows

    @follows = Following.shard(@u.uid).where(uid: @u.uid).select('id, following_uid').order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    if @follows.size > 0
      following_uids = @follows.collect{|f| f.following_uid}
      @users = $profile_client.getMultiUserBasicInfos(following_uids)
      @following_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, following_uids)
      @following_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, following_uids)
      @follow_status = {}
      if @current_uid
        followings = Following.shard(@current_uid).where(uid: @current_uid, following_uid: following_uids).select('following_uid, is_mutual')
        followings.each do |follow|
          @follow_status[follow.following_uid] = [true,follow.is_mutual]
        end
      end
    end

    check_follow_status(@u.uid)

    @this_title = "#{@u.nickname}关注的人 喜马拉雅-听我想听"
  end

  def init_my_fans_page

    query = ["nickname like ?", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.follows

    @followers_count = $counter_client.get(Settings.counter.user.followers, @current_uid)

    all_follwers = Follower.shard(@current_uid).where(following_uid: @current_uid).where(query)
    @followers = all_follwers.select('id, uid').order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    follower_uids = @followers.collect{|f| f.uid}

    if follower_uids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(follower_uids)
      @follower_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, follower_uids)
      @follower_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, follower_uids)
      @follow_status = {}
      if @current_uid
        followings = Following.shard(@current_uid).where(uid: @current_uid, following_uid: follower_uids).select('following_uid, is_mutual')
        followings.each do |follow|
          @follow_status[follow.following_uid] = [true,follow.is_mutual]
        end
      end
    else
      @users = {}
      @follower_tracks_counts = []
      @follower_followers_counts = []
      @follow_status = {}
    end

    $counter_client.set(Settings.counter.user.new_follower, @current_uid, 0) if @page==1
    
    @this_title = "我的粉丝 喜马拉雅-听我想听"
  end

  def init_his_fans_page

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @page=1 if @page > 10 #只显示前10页列表,之后的页码显示第一页列表
    @per_page = Settings.per_page.follows

    @followers_count = $counter_client.get(Settings.counter.user.followers, @u.uid)

    all_follwers = Follower.shard(@u.uid).where(following_uid: @u.uid)
    @followers = all_follwers.select('id, uid').order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    follower_uids = @followers.collect{|f| f.uid}

    if follower_uids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(follower_uids)
      @follower_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, follower_uids)
      @follower_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, follower_uids)
      @follow_status = {}
      if @current_uid
        followings = Following.shard(@current_uid).where(uid: @current_uid, following_uid: follower_uids).select('following_uid, is_mutual')
        followings.each do |follow|
          @follow_status[follow.following_uid] = [true,follow.is_mutual]
        end
      end
    else
      @users = {}
      @follower_tracks_counts = []
      @follower_followers_counts = []
      @follow_status = {}
    end

    check_follow_status(@u.uid)

    @this_title = "#{@u.nickname}的粉丝 喜马拉雅-听我想听"
  end

  def init_my_favorites_page

    query = ["title like ?", "%#{params[:q]}%"] if params[:q].present?  #搜索条件

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.favorites

    order = (["created_at desc" , "created_at asc"].include?(params[:order]) && params[:order]) || "created_at desc"
    all_favorites = Favorite.shard(@current_uid).where(uid: @current_uid).where(query)
    @favorites_count = all_favorites.count
    @favorites = all_favorites.order(order).offset((@page-1)*@per_page).limit(@per_page)
    
    track_ids,track_uids = [],[]
    @favorites.each do |f|
      track_ids << f.track_id
      track_uids << f.track_uid
    end

    if track_ids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(track_uids)
      @track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
      @track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, track_ids)
    else
      @users = {}
      @track_plays_counts = []
      @track_favorites_counts = []
      @track_shares_counts = []
      @track_comments_counts = []
    end
    @this_title = "我喜欢的声音 喜马拉雅-听我想听"
  end

  def init_his_favorites_page
    
    query = ["title like ?", "%#{params[:q]}%"] if params[:q].present?  #搜索条件
    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.favorites

    order = (["created_at desc" , "created_at asc"].include?(params[:order]) && params[:order]) || "created_at desc"
    all_favorites = Favorite.shard(@u.uid).where(uid: @u.uid).where(query)
    @favorites_count = all_favorites.count
    @favorites = all_favorites.order(order).offset((@page-1)*@per_page).limit(@per_page)
    
    track_ids,track_uids = [],[]
    @favorites.each do |f|
      track_ids << f.track_id
      track_uids << f.track_uid
    end
    
    if track_ids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(track_uids)
      @track_plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @track_favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
      @track_shares_counts = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @track_comments_counts = $counter_client.getByIds(Settings.counter.track.comments, track_ids)
    else
      @users = {}
      @track_plays_counts = []
      @track_favorites_counts = []
      @track_shares_counts = []
      @track_comments_counts = []
    end

    check_follow_status(@u.uid)

    @this_title = "#{@u.nickname}喜欢的声音 喜马拉雅-听我想听"
  end

  def get_podcast_categories
    {
      'Arts'=>{
        'text'=>'艺术',
        'sub_category'=>{
          'Design'=> '设计',
          'Fashion &amp; Beauty'=>'时尚美容',
          'Food'=>'美食',
          'Literature'=>'文学',
          'Performing Arts'=>'表演艺术',
          'Visual Arts'=>'视觉艺术'
        }
      },
      'Business'=>{
        'text'=>'商业',
        'sub_category'=>{
          'Business News'=> '财经新闻',
          'Careers'=>'职场',
          'Investing'=>'投资',
          'Management &amp; Marketing'=>'管理与营销',
          'Shopping'=>'购物'
        }
      },
      'Comedy'=>{
        'text'=>'喜剧',
        'sub_category'=>{}
      },
      'Education'=>{
        'text'=>'教育',
        'sub_category'=>{
          'Education'=> '教育',
          'Education Technology'=>'教育技术',
          'Higher Education'=>'高等教育',
          'K-12'=>'基础教育',
          'Language Courses'=>'语言课程',
          'Training'=>'培训'
        }
      },
      'Games &amp; Hobbies'=>{
        'text'=>'游戏爱好',
        'sub_category'=>{
          'Automotive'=> '汽车',
          'Aviation'=>'航空',
          'Hobbies'=>'爱好',
          'Other Games'=>'其他游戏',
          'Video Games'=>'视频游戏'
        }
      },
      'Government &amp; Organizations'=>{
        'text'=>'政府与组织',
        'sub_category'=>{
          'Local'=> '地方性',
          'National'=>'全国性',
          'Non-Profit'=>'非盈利性',
          'Regional'=>'区域性'
        }
      },
      'Health'=>{
        'text'=>'健康',
        'sub_category'=>{
          'Alternative Health'=> '另类保健',
          'Fitness &amp; Nutrition'=>'健身与营养',
          'Self-Help'=>'励志自助',
          'Sexuality'=>'两性'
        }
      },
      'Kids &amp; Family'=>{
        'text'=>'儿童与家庭',
        'sub_category'=>{}
      },
      'Music'=>{
        'text'=>'音乐',
        'sub_category'=>{}
      },
      'News &amp; Politics'=>{
        'text'=>'时事政治',
        'sub_category'=>{}
      },
      'Religion &amp; Spirituality'=>{
        'text'=>'宗教与精神生活',
        'sub_category'=>{
          'Buddhism'=>'佛教',
          'Christianity'=>'基督教',
          'Hinduism'=>'印度教',
          'Islam'=>'伊斯兰教',
          'Judaism'=>'犹太教',
          'Other'=>'其他',
          'Spirituality'=>'精神生活'
        }
      },
      'Science &amp; Medicine'=>{
        'text'=>'科学与医学',
        'sub_category'=>{
          'Medicine'=>'医学',
          'Natural Sciences'=>'自然科学',
          'Social Sciences'=>'社会科学'
        }
      },
      'Society &amp; Culture'=>{
        'text'=>'社会与文化',
        'sub_category'=>{
          'History'=>'历史',
          'Personal Journals'=>'个人杂志',
          'Philosophy'=>'哲学',
          'Places &amp; Travel'=>'景点与旅游'
        }
      },
      'Sports &amp; Recreation'=>{
        'text'=>'运动休闲',
        'sub_category'=>{
          'Amateur'=>'业余爱好者',
          'College &amp; High School'=>'大学与中学',
          'Outdoor'=>'户外',
          'Professional'=>'专业人士'
        }
      },
      'Technology'=>{
        'text'=>'科技',
        'sub_category'=>{
          'Gadgets'=>'科技酷品',
          'Tech News'=>'科技资讯',
          'Podcasting'=>'Podcasting',
          'Software How-To'=>'软件技巧'
        }
      },
      'TV &amp; Film'=>{
        'text'=>'影视',
        'sub_category'=>{}
      },
    }
  end

end
