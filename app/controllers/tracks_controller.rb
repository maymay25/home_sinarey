class TracksController < ApplicationController

  include UploadsHelper

  set :views, ['tracks','application']

  def dispatch(action,params_options={})
    params_options.each {|k,v| params[k] = v }
    super(:tracks,action)
    method(action).call
  end

  #声音详情页
  def show_page

    redirect_to_root

    set_no_cache_header

    @track = Track.fetch(params[:id])

    halt_404 if @track.nil? or @track.is_deleted

    is_own = @track.uid == @current_uid

    if @track.is_public
      return halt_status0 if @track.status == 0 && !is_own
      return halt_status2 if @track.status == 2
    else
      return halt_404 if !is_own
    end

    # 是否已收藏
    @is_favorited = @current_uid ? Favorite.shard(@current_uid).where(uid: @current_uid, track_id: @track.id).any? : false

    # 声音相关计数
    @comments_count, @favorites_count, @plays_count, @shares_count = $counter_client.getByNames([
        Settings.counter.track.comments,
        Settings.counter.track.favorites,
        Settings.counter.track.plays,
        Settings.counter.track.shares
      ], @track.id)

    @category_name,@category_title = nil,nil
    if @track.category_id
      category = Category.where(id: @track.category_id).first
      if category
        @category_name = category.name 
        @category_title = category.title
      end
    end

    @track_user = get_profile_user_basic_info(@track.uid)

    check_follow_status(@track_user.uid)

    set_no_cache_header
    @this_title = "#{@track.title} 喜马拉雅-听我想听"

    halt erb_js(:show_js) if request.xhr?
    erb :show
  end

  #声音详情页中转页
  def track_show0

    set_no_cache_header

    tir = TrackInRecord.fetch(params[:id])
    
    halt_404 unless tir

    redirect "/#{tir.uid}/sound/#{tir.track_id}", status: 303
  end

  #赞声音的用户列表页
  def liker_page

    redirect_to_root

    set_no_cache_header

    @tir = TrackInRecord.fetch(params[:id])

    halt_404 if @tir.nil? or (!@tir.is_public && @tir.uid != @current_uid) or @tir.is_deleted or @tir.status != 1

    @u = get_profile_user_basic_info(@tir.uid)

    @track_record = TrackRecord.shard(@tir.uid).where(uid: @tir.uid, track_id: @tir.track_id, is_deleted: false).first
    @track_rich = TrackRich.shard(@tir.track_id).where(track_id: @tir.track_id).first

    @all_track_records = TrackInRecord.shard(@tir.track_id).where("album_id is not null and track_id = ?", @tir.track_id).limit(6)

    @is_favorited = @current_uid ? Favorite.shard(@current_uid).where(uid: @current_uid, track_id: @tir.track_id).any? : false

    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    all_lover = Lover.shard(@tir.track_id).where(track_id: @tir.track_id)

    @lovers_count = all_lover.count
    lovers = all_lover.select('id, uid').order("created_at desc").offset((@page-1)*@per_page).limit(@per_page)
    
    @follow_status = {}
    lover_uids = lovers.collect{|l| l.uid}
    if lover_uids.size > 0
      profile_users = $profile_client.getMultiUserBasicInfos(lover_uids)
      @lovers = lover_uids.collect{ |uid| profile_users[uid] }
      @lover_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, lover_uids)
      @lover_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, lover_uids)
      @lover_followings_counts = $counter_client.getByIds(Settings.counter.user.followings, lover_uids)
      if @current_uid
        follows = Following.shard(@current_uid).where(uid: @current_uid, following_uid: lover_uids).select('following_uid, is_mutual')
        follows.each do |follow|
          @follow_status[follow.following_uid] = [true,follow.is_mutual]
        end
      end
    else
      @lovers = []
      @lover_tracks_counts = []
      @lover_followers_counts = []
      @lover_followings_counts = []
    end

    @track_play_count = $counter_client.get(Settings.counter.track.plays, @tir.track_id.to_s)
    @track_share_count = $counter_client.get(Settings.counter.track.shares, @tir.track_id.to_s)

    @track_favorite_count = Lover.shard(@tir.track_id).where(track_id: @tir.track_id).count
    lovers_counter = $counter_client.get(Settings.counter.track.favorites, @tir.track_id.to_s)
    if lovers_counter != @track_favorite_count
      $counter_client.set(Settings.counter.track.favorites, @tir.track_id, @track_favorite_count)
    end

    if @tir.uid == @current_uid
      set_my_counts 
    else
      set_his_counts(@tir.uid)
    end

    check_follow_status(@tir.uid)
    
    @this_title = "喜欢#{@tir.title}的人 喜马拉雅-听我想听"

    halt erb_js(:liker_js) if request.xhr?
    erb :liker
  end

  #赞声音
  def do_like_track

    halt_400 unless @current_uid

    $xunch["track_set"].evict(params[:track_id])

    track = Track.fetch(params[:track_id])
    halt render_json({res: false, message: "", msg: '该声音不存在'}) if track.nil? or track.is_deleted

    halt render_json({res: false, message: "", msg: '抱歉，该声音正在审核中'}) if track.status == 0

    halt render_json({res: false, message: "", msg: '该声音已经下架'}) if track.status != 1

    halt render_json({res: false, message: "", msg: '私密声音不能赞'}) unless track.is_public

    #黑名单
    halt render_json({res: false, message: "", msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid: track.uid, black_uid: @current_uid).first

    unless Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track.id).any?

      fav = Favorite.create(uid: @current_uid,
        track_id: track.id,
        track_uid: track.uid,
        track_upload_source: track.upload_source,
        upload_source: 2,
        waveform: track.waveform,
        upload_id: track.upload_id
      )

      topic_hash = fav.to_topic_hash
      current_ps = PersonalSetting.where(uid: @current_uid).first
      topic_hash[:is_feed] = current_ps.nil? || current_ps.is_feed_favorite==true

      $rabbitmq_channel.fanout(Settings.topic.favorite.created, durable: true).publish(oj_dump(topic_hash), content_type: 'text/plain', persistent: true)

      $counter_client.incr(Settings.counter.user.favorites, @current_uid, 1)

      $counter_client.incr(Settings.counter.track.favorites, fav.track_id, 1)

      # 同步分享确认, 不再提示
      if params[:no_more_alert] and !params[:no_more_alert].empty?
        $sync_set_client.noMoreFavoriteSyncAlert(@current_uid, params[:no_more_alert]=='true')
      end

      CoreAsync::FavoriteCreatedWorker.perform_async(:favorite_created,fav.id,fav.uid,2,params[:sharing_to],Settings.home_root)

    end

    halt render_json({res: true, msg: print_message(:success)})
  end

  #取消赞声音
  def cancel_like_track

    halt_400 unless @current_uid

    fav = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: params[:track_id]).first
    if fav
      fav.destroy

      # 发已删除topic
      $rabbitmq_channel.fanout(Settings.topic.favorite.destroyed, durable: true).publish(oj_dump({
        id: fav.id,
        uid: fav.uid,
        track_id: fav.track_id,
        updated_at: Time.new
      }), content_type: 'text/plain', persistent: true)


      $counter_client.decr(Settings.counter.user.favorites, @current_uid, 1)

      # 更新声音的收藏计数
      $counter_client.decr(Settings.counter.track.favorites, fav.track_id, 1)
    end

    halt render_json({res: true, msg: print_message(:success)})
  end

  #播放统计 params: duration played_secs
  def do_play_track

    track_id = (tmp=params[:id].to_i)>0 ? tmp : nil
    halt '' unless track_id

    current_now = Time.now
    uuid = SecureRandom.uuid.gsub('-', '')
    rk = "#{current_now.to_i}_#{params[:id]}_#{uuid}"
    if @current_user
      is_v = @current_user.isVerified
      if @current_user.thirdpartyName
        tpname = @current_user.thirdpartyName['name']
      end
    end

    $counter_client.incr(Settings.counter.track.plays, track_id, 1) # 同步加播放数

    $rabbitmq_channel.fanout(Settings.topic.track.played, durable: true).publish(Oj.dump({
      client: params[:device] || 'web',
      ip: get_client_ip,
      user_agent: request.user_agent,
      referer: env['referer'],
      uid: @current_uid,
      isVerified: is_v,
      thirdpartyName: tpname,
      id: params[:id],
      duration: params[:duration],
      started_at: current_now,
      played_secs: params[:played_secs],
      rk: rk,
      uuid: params[:uuid] || uuid
    }, mode: :compat), content_type: 'text/plain', persistent: true)

    halt ''
  end

  # 转发声音
  def do_relay_track

    halt_400 unless @current_uid
    
    halt_403({res: false, message: "", msg: '对不起，您已被暂时禁止发表内容'}) if @current_user.isLoginBan or is_user_banned?(@current_uid)

    track = Track.shard(params[:id]).where(id: params[:id]).first
    halt render_json({res:false, error:"failure", msg:"声音不存在或者已经被删除"}) if track.nil? or track.is_deleted

    # 自己的声音不能转发
    halt render_json({res:false, error:"failure", msg:"自己的声音不能转发"}) if track.uid == @current_uid

    halt render_json({res:false, error:"failure", msg:"抱歉，该声音正在审核中"}) if track.status == 0

    halt render_json({res:false, error:"failure", msg:"该声音已经下架"}) if track.status != 1

    halt render_json({res: false, message: "", msg: '私密声音不能转发'}) unless track.is_public

    # 只能转发一次
    my_trackrecords_count = TrackRecord.shard(@current_uid).where(uid: @current_uid, track_id: track.id, is_public: true, is_deleted: false, status: 1).count
    halt render_json({res: false, error: 2,msg: "你已经转采了该声音"}) if my_trackrecords_count > 0

    #黑名单
    halt render_json({res: false, message: "", msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid: track.uid,black_uid:@current_uid).first

    content = params[:content].presence
    if content
      res = $wordfilter_client.wordFilters(5, @current_uid, get_client_ip, content)
      if res == -11
        halt render_json({res: false, message: "", msg: "评论内容非法"})
      elsif res == -19
        halt render_json({res: false, message: "", msg: "评论内容包含不支持的字符，请修改！"})
      end
    end
    
    # 记录我转发的声音
    record_hash = {
      track_id: track.id,
      track_uid: track.uid, # 原声音发布者
      op_type: TrackRecordTemp::OP_TYPE[:RELAY],
      is_public: true,
      is_publish: true,
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
      comment_content: "",  # 异步添加值
      comment_id: nil,  # 异步添加值
      waveform: track.waveform,
      upload_id:track.upload_id,
      status: 1
    }
    record = TrackRecord.create(record_hash)

    # 声音的转发数  +1
    $counter_client.incr(Settings.counter.track.shares, track.id, 1)

    #同步到Origin表
    record_origin = TrackRecordOrigin.new
    record_origin.id = record.id
    record_origin.created_at = record.created_at
    record_origin.updated_at = record.updated_at
    record_origin.update_attributes(record_hash)

    sharing_to = params[:sharing_to]
    share_content = cut_str(content.to_s.strip, 60, '..')

    CoreAsync::RelayCreatedWorker.perform_async(:relay_created,track.id,content,@current_uid,record.id,sharing_to)

    $rabbitmq_channel.fanout(Settings.topic.track.relay, durable: true).publish(oj_dump(track.to_topic_hash.merge({
      id: record.id,
      content: content, 
      sharing_to: sharing_to, 
      relay_uid: @current_uid, 
      relay_nickname: @current_user.nickname, 
      relay_avatar_path: @current_user.logoPic, 
      relay_content: share_content, 
      track_id: track.id, 
      track_record_id: record.id,
      upload_source: 2, 
      human_category_id: @current_user.vCategoryId,
      created_at: Time.now,
      ip: get_client_ip
    })), content_type: 'text/plain', persistent: true)

    halt render_json({ res: true })
  end

  # 私密声音转公开
  def do_set_public

    halt_400 unless @current_uid

    halt render_json({res: false}) unless params[:record_id]

    record = TrackRecord.shard(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false).first
    halt render_json({res: false}) unless record

    track = Track.shard(record.track_id).where(id: record.track_id, is_deleted: false).first
    halt render_json({res: false}) if track.nil? or track.uid != @current_uid or track.is_public

    record.update_attribute(:is_public, true)
    track.update_attribute(:is_public, true)

    if track.status == 1
      $counter_client.incr(Settings.counter.user.tracks, track.uid, 1)
      if track.album_id
        $counter_client.incr(Settings.counter.album.tracks, track.album_id, 1)
      end
    end

    CoreAsync::TrackOnWorker.perform_async(:track_on, track.id, false, nil, nil)
    $rabbitmq_channel.fanout(Settings.topic.track.created, durable: true).publish(oj_dump(track.to_topic_hash.merge(user_agent: request.user_agent, is_feed: true, ip: get_client_ip)), content_type: 'text/plain', persistent: true)
    bunny_logger ||= ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
    bunny_logger.info "track.created.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"

    halt render_json({res: true, message: '改动已生效'})
  end

  def get_album_list

    set_no_cache_header

    list = []
    albums = Album.shard(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1)
    albums.each do |album|
      list << {id: album.id, title: CGI::escapeHTML(album.title ? album.title[0..30] : '')}
    end

    halt render_json({response: list})
  end

  # 添加到专辑
  def do_join_album

    halt render_json({res: false, error: "failure"}) unless @current_uid
    
    halt render_json({res: false, error: "failure"}) unless params[:record_id]

    record = TrackRecord.shard(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false, status: 1).first
    halt render_json({res: false, error: "failure"}) unless record
    
    old_album_id = record.album_id
    track = Track.shard(record.track_id).where(id: record.track_id, is_public: true, is_deleted: false, status: 1).first if record
    halt render_json({res: false,  error: 'track not exsit'}) unless track

    if params[:album_id] # 选择已存在的专辑

      album = TrackSet.shard(params[:album_id]).where(uid: @current_uid, id: params[:album_id], is_deleted: false, status: 1).first
      halt render_json({res: false, error: "failure"}) if album.nil?

      album_track_count = TrackRecord.shard(@current_uid).where(uid: @current_uid, album_id: album.id, is_deleted: false, status: [0,1]).count
      delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count
      temp_track_count = TempAlbumForm.where(uid: @current_uid, state: 0, album_id: album.id).sum('add_tracks') # 专辑缓存表中的数据也算上
      allcount = album_track_count + delayed_track_count + temp_track_count + 1
      halt render_json({res: false, error: "album_full"}) if allcount > 200

      unless album.id == old_album_id
        track.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path) if record.op_type == 1
        record.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path)

        # 将该声音添加到新专辑的声音序列
        update_attrs = {}
        if album.records_order
          if album.is_records_desc
            this_records_order = ( [params[:record_id]] + album.records_order.split(",") ).join(",")
          else
            this_records_order = album.records_order.split(",").push(params[:record_id]).join(",")
          end
          update_attrs[:records_order] = this_records_order
        end
        album.update_attributes(update_attrs) unless update_attrs == {}

        if track.is_public && track.status == 1
          $counter_client.incr(Settings.counter.album.tracks, album.id, 1)
          $counter_client.decr(Settings.counter.album.tracks, old_album_id, 1) if old_album_id
        end

        CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,false,request.user_agent,get_client_ip,nil,nil,[[record.id, old_album_id]],nil,nil,nil,nil)
      end
    elsif params[:album_title] and !params[:album_title].strip.empty?

      if Settings.is_check_mobile
        halt render_json({res: false, errors: [['mobile', '请先绑定手机']]}) unless @current_user.mobile
      end

      # 专辑信息脏字
      album_dirts = filter_hash(3, @current_user, get_client_ip, {
        album_title: params[:album_title],
        album_intro: params[:album_intro]
      })
      
      halt render_json({res: false, errors: [['dirty_words', album_dirts]]}) if album_dirts.size > 0

      # 创建新专辑
      album = Album.new
      album.title = params[:album_title]
      album.intro = params[:album_intro] || ""
      album.short_intro = (params[:album_intro] &&  params[:album_intro][0,100])
      album.uid = @current_uid
      album.nickname = @current_user.nickname
      album.avatar_path = @current_user.logoPic
      album.is_v = @current_user.isVerified
      album.dig_status = calculate_dig_status(@current_user)
      album.human_category_id = @current_user.vCategoryId
      album.category_id = track.category_id
      album.tags = track.tags
      album.cover_path = track.cover_path
      album.user_source = track.user_source
      album.is_publish = true
      album.is_public = true
      album.status = calculate_default_status(@current_user)
      album.records_order = params[:record_id]
      album.save

      track.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path) if record.op_type == 1
      record.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path)

      if album.status == 1
        $counter_client.incr(Settings.counter.user.albums, album.uid, 1)
        $counter_client.incr(Settings.counter.album.tracks, album.id, 1)
      end

      #老专辑声音数同步减1
      $counter_client.decr(Settings.counter.album.tracks, old_album_id, 1) if old_album_id && track.status == 1 && track.is_public

      CoreAsync::AlbumUpdatedWorker.perform_async(:album_updated,album.id,true,request.user_agent,get_client_ip,nil,nil,[[record.id, old_album_id]],nil,nil,nil,nil)
    end

    halt render_json({res: true, id: album.id, title: CGI::escapeHTML(album.title)})
  end

  # 删除声音
  def do_destroy_track

    halt_400 unless @current_uid

    record = TrackRecord.shard(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false).first
    halt render_json({res: false, msg: "该声音已删除"}) unless record

    record.update_attribute(:is_deleted,true)

    if record.album_id
      album = TrackSet.shard(record.album_id).where(uid: @current_uid, id: record.album_id, is_deleted: false).first
      #更新专辑的声音排序   #维护专辑的'最后更新声音'(在异步脚本中实现)
      if album
        if album.records_order
          this_records_order = album.records_order.split(",").delete_if{ |record_id| "#{record_id}" == "#{params[:record_id]}" }.join(",")
          album.records_order = this_records_order
        end
        album.save
      end
    end

    if record.op_type == TrackRecordTemp::OP_TYPE[:UPLOAD]
      track = Track.shard(record.track_id).where(id: record.track_id, is_deleted: false).first
      if track
        old_is_deleted = track.is_deleted
        track.update_attribute(:is_deleted, true)

        is_off = !old_is_deleted && track.is_public && track.status == 1
        $rabbitmq_channel.fanout(Settings.topic.track.destroyed, durable: true).publish(Oj.dump(track.to_topic_hash.merge(is_feed: true, is_off: is_off, ip: get_client_ip), mode: :compat), content_type: 'text/plain', persistent: true)
        bunny_logger ||= ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
        bunny_logger.info "track.destroyed.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"
      end
    elsif record.op_type == TrackRecordTemp::OP_TYPE[:RELAY]
      $counter_client.decr(Settings.counter.user.tracks, record.uid, 1)
      $counter_client.decr(Settings.counter.track.shares, record.track_id, 1)

      # 转采的声音 所在专辑的声音数 -1
      if record.album_id
        $counter_client.decr(Settings.counter.album.tracks, record.album_id, 1)
      end

      $rabbitmq_channel.fanout(Settings.topic.track.relay_destroyed, durable: true).publish(oj_dump({
        id: record.id, track_id: record.track_id, uid: record.uid, created_at: record.created_at, is_feed: true, ip: get_client_ip
      }), content_type: 'text/plain', persistent: true)
    end

    halt render_json({res: true, msg: print_message(:success)})
  end

  # 评论列表
  def track_comment_list_template

    set_no_cache_header

    @track = Track.fetch(params[:id])

    halt '' if @track.nil? or @track.is_deleted or @track.status != 1

    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.track_comments

    all_comments = Comment.shard(@track.id).where(track_id: @track.id, parent_id: nil, is_deleted:false).order('id desc')

    @comments_count = all_comments.count
    @comments = all_comments.offset((@page-1)*@per_page).limit(@per_page)
    all_uid_hash = {}
    @comments.each do |c|
      all_uid_hash[c.uid] = 1
    end

    sql_list = []
    @comments.each do |comment|
      sql = Comment.shard(@track.id).where(track_id: @track.id, parent_id: comment.id, is_deleted:false).limit(50).to_sql
      sql_list << sql
    end
    union_sql = sql_list.collect{|sql| "(#{sql})" }.join(" union all ")
    all_replies = union_sql.present? ? Comment.find_by_sql(union_sql) : []

    @replies = {}
    all_replies.each do |c|
      (@replies[c.parent_id] ||= []) << c
      all_uid_hash[c.uid] = 1
    end

    all_uids = all_uid_hash.keys
    if all_uids.length > 0
      @profile_users = $profile_client.getMultiUserBasicInfos(all_uids)
    else
      @profile_users = {}
    end

    render_to_string(partial: :_track_comment_list)
  end

  # 转采列表
  def track_relay_list_template
    set_no_cache_header
    render_to_string(partial: :_track_relay_list)
  end


  ##ajax 评论列表(feed列表)
  def feed_comment_list_template

    set_no_cache_header

    @track = Track.fetch(params[:id])
    halt '' if @track.nil? or @track.is_deleted or @track.status != 1
    @comments_count = Comment.shard(@track.id).where(track_id: @track.id).count
    @comments = Comment.shard(@track.id).where(track_id: @track.id).order('id desc').limit(10)

    uids = @comments.map(&:uid)
    @users = $profile_client.getMultiUserBasicInfos(uids)

    render_to_string(partial: :_feed_comment_list)
  end

  ##ajax 该声音被这些人转采(feed列表)
  def feed_relay_list_template

    set_no_cache_header

    @track = Track.fetch(params[:id])
    halt '' if @track.nil? or @track.is_deleted or @track.status != 1
    all_reposts = TrackRepost.shard(@track.id).where(track_id: @track.id, op_type: 2)
    @relays_count = all_reposts.count
    @relays = all_reposts.order("id desc").limit(10)
    render_to_string(partial: :_feed_relay_list)
  end

  # 你可能还喜欢
  def maybe_like_list_template

    set_no_cache_header

    track = Track.fetch(params[:id])
    halt '' if track.nil? or track.is_deleted or track.status != 1

    render_to_string(partial: :_maybe_like_list, locals: { category_id: track.category_id || 0 })
  end

  # 右侧 他的其它声音，广告，收录专辑，喜欢该声音的人，扫一扫
  def right_template

    set_no_cache_header

    track = Track.fetch(params[:id])
    halt '' if track.nil? or track.is_deleted or track.status != 1
    
    render_to_string(partial: :_right, locals: {track: track})
  end

  # 声音详细展开
  def rich_intro_template

    set_no_cache_header

    @track = Track.fetch(params[:id])
    halt '' if @track.nil? or @track.is_deleted or @track.status != 1
    
    @track_user = get_profile_user_basic_info(@track.uid)

    render_to_string(partial: :_rich_intro)
  end

  # 声音列表，ajax载入播放器片段，主要处理没有波形的情况
  def expend_box_template

    set_no_cache_header

    @tir = TrackInRecord.fetch(params[:id])
    halt '' if @tir.nil? or @tir.is_deleted or @tir.status != 1

    # 是否已收藏
    @is_favorited = @current_uid && Favorite.shard(@current_uid).where(uid: @current_uid, track_id: @tir.track_id).any?

    # 声音相关计数
    @comments_count, @favorites_count, @plays_count, @shares_count = $counter_client.getByNames([
        Settings.counter.track.comments,
        Settings.counter.track.favorites,
        Settings.counter.track.plays,
        Settings.counter.track.shares
      ], @tir.track_id)
    
    render_to_string(partial: :_expend_box)
  end

  #声音的图片 多图
  def get_pictures

    set_no_cache_header

    track_id = params[:id].to_i
    halt render_json({ret:0,msg:'缺少参数 id'}) unless track_id>0
    
    track_pictures = TrackPicture.shard(track_id).where(track_id:track_id).order("order_num asc")
    if track_pictures.length==0
      tir = TrackInRecord.fetch(track_id)
      track_pictures = [{'picture_path'=>tir.cover_path}] if tir
    end

    pictures = []
    track_pictures.each do |t|
      if t['picture_path']
        large_pic = picture_url('track', t['picture_path'], 'origin')
      else
        large_pic = picture_url('track', nil, '640')
      end
      pictures << {
        small: picture_url('track', t['picture_path'], '180'),
        large: large_pic
      }
    end
    if pictures.length>0
      halt render_json({ret:1,pictures:pictures})
    else
      halt render_json({ret:0,msg:"该声音的图片已被删除"})
    end
  end

  #声音的分块头像
  def get_track_blocks_avatars
    set_no_cache_header
    halt '' unless params[:track_ids]

    res = {}
    params[:track_ids].split(',').each do |track_id|
      tb = TrackBlock.shard(track_id).where(track_id: track_id).first
      halt '' unless tb

      bash = {}
      BlockAvatar.shard(track_id).where(track_id: track_id).select('block_id, avatar_path, created_at').order('created_at desc').each do |ba|
        if bash.key?(ba.block_id)
          bash[ba.block_id] << picture_url('header', ba.avatar_path, 16)
        else
          bash[ba.block_id] = [ picture_url('header', ba.avatar_path, 16) ]
        end
      end

      res[track_id] = [ tb.blocks, bash, tb.duration ]
    end

    render_json(res)
  end

  # 声音指定块里的评论列表
  def get_track_blocks_comments

    set_no_cache_header
    block_idx = params[:block_idx].to_i # 第几块
    tb = TrackBlock.shard(params[:track_id]).where(track_id: params[:track_id]).first

    halt render_json({ count: 0, comments: nil, msg: print_message(:record_not_found, "track_id: #{params[:track_id]}") }) unless tb

    halt render_json({ count: 0, comments: nil,msg: print_message(:validation_failed, "index: #{block_idx}, track blocks: #{tb.blocks}") }) if block_idx > tb.blocks

    comments_count = tb.send("b#{block_idx}")

    comments = Comment.shard(tb.track_id).where(track_id: tb.track_id, block: block_idx).order('created_at desc').limit(Settings.per_page.track_block_comments).select('content, created_at, id, nickname, avatar_path, parent_id, second, track_id, uid')

    comments_h = [].tap do |arr|
      comments.each do |comment|
        arr << {
          content: puts_face(comment.content), 
          created_at: comment.created_at, 
          id: comment.id, 
          nickname: comment.nickname, 
          avatar_url: picture_url('header', comment.avatar_path, 16),
          parent_id: comment.parent_id, 
          second: comment.second, 
          track_id: comment.track_id, 
          uid: comment.uid
        }
      end
    end

    render_json({ count: comments_count, comments: comments_h })
  end

  def get_track_json
    set_no_cache_header
    track = Track.fetch(params[:id])

    halt '' if (track.nil? or track.is_deleted or track.status == 2 or ( (track.status == 0 or !track.is_public) and track.uid != @current_uid) )

    this_category = CATEGORIES[track.category_id]

    play_count, comments_count, shares_count, favorites_count = $counter_client.getByNames([
        Settings.counter.track.plays,
        Settings.counter.track.comments,
        Settings.counter.track.shares,
        Settings.counter.track.favorites
      ], track.id)

    if track.uid==@current_uid
      user = @current_user
    else
      user = get_profile_user_basic_info(track.uid)
    end

    album = TrackSet.fetch(track.album_id) if track.album_id

    track_hash = {
      id: track.id,
      play_path_64: track.play_path_64,
      play_path_32: track.play_path_32,
      play_path_128: track.play_path_128,
      play_path: track.play_path,
      duration: track.duration,
      title: track.title,
      nickname: user && user.nickname,
      uid: track.uid,
      waveform: track.waveform,
      upload_id: track.upload_id,
      cover_url: file_url(track.cover_path),
      cover_url_142: picture_url('track', track.cover_path, '180'),
      formatted_created_at: track.created_at.strftime('%-m月%-d日 %H:%M'),
      is_favorited: nil,
      play_count: play_count,
      comments_count: comments_count,
      shares_count: shares_count,
      favorites_count: favorites_count,
      title: track.title,
      album_id: track.album_id,
      album_title: album && album.title,
      intro: track.intro,
      short_intro: track.short_intro,
      have_more_intro: track.intro ? track.intro.length > 100 : false,
      time_until_now: parse_time_until_now(track.created_at),
      category_name: this_category.name,
      category_title: this_category.title,
      played_secs: nil
    }

    render_json(track_hash)
  end

  def get_multi_tracks_json

    set_no_cache_header
    ids = params[:ids].to_s.split('_')
    halt '' if ids.size == 0

    play_counts = $counter_client.getByIds(Settings.counter.track.plays, ids)
    comments_counts = $counter_client.getByIds(Settings.counter.track.comments, ids)
    shares_counts = $counter_client.getByIds(Settings.counter.track.shares, ids)
    favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, ids)

    tirs = TrackInRecord.mfetch(ids)

    arr = []
    tirs.each_with_index do |tir, i|
      if tir.nil? or (!tir.is_public and tir.track_uid != @current_uid) or tir.is_deleted or tir.status != 1
        arr << nil
      else
        arr << TrackInRecord.hashlize(tir).merge({
          id: tir.track_id,
          cover_url: file_url(tir.cover_path),
          cover_url_142: picture_url('track', tir.cover_path, '180'),
          formatted_created_at: tir.created_at.strftime('%-m月%-d日 %H:%M'),
          is_favorited: @current_uid ? Favorite.shard(@current_uid).where(uid: @current_uid, track_id: tir.track_id).any? : false,
          play_count: play_counts[i],
          comments_count: comments_counts[i],
          shares_count: shares_counts[i],
          favorites_count: favorites_counts[i],
          title: tir.title ? CGI::escapeHTML(tir.title) : '',
          album_title: tir.album_title ? CGI::escapeHTML(tir.album_title) : '',
          intro: tir.intro ? CGI::escapeHTML(tir.intro) : '',
          short_intro: tir.short_intro ? CGI::escapeHTML(tir.short_intro) : '',
          time_until_now: parse_time_until_now(tir.created_at)
        })
      end
    end
    
    render_json(arr)
  end

  #编辑声音 表单页
  def edit_page

    halt_404 if request.xhr?

    return redirect_to_login unless @current_uid

    @record = TrackRecord.shard(@current_uid).where(uid: @current_uid, id: params[:id], is_deleted: false).first

    halt_error('声音已删除或者不存在') if @record.nil? or @record.op_type != TrackRecordTemp::OP_TYPE[:UPLOAD]

    set_no_cache_header

    trackrich = TrackRich.shard(@record.track_id).where(track_id: @record.track_id).first
    if trackrich
      @lyric = Sanitize.clean(CGI.unescapeHTML(trackrich.lyric), { elements: %w(br) }) if trackrich.lyric.presence
      @rich_intro = CGI.unescapeHTML(trackrich.rich_intro)
    end

    @category = CATEGORIES[@record.category_id]

    @track_pictures = TrackPicture.shard(@record.track_id).where(track_id:@record.track_id).order("order_num asc")

    @album_list = Album.shard(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1)

    @this_title = "编辑声音 喜马拉雅-听我想听"

    erb :edit_page
  end



  #上传声音 表单页
  def upload_page

    halt_404 if request.xhr?

    halt_400 unless @current_uid

    halt_403 if @current_user.isLoginBan or is_user_banned?(@current_uid)

    set_no_cache_header

    @user_tags = UserTag.shard(@current_uid).where(uid: @current_uid).order("num desc").limit(15)

    @default_category = CHOOSE_CATEGORIES[0]
    @tags = HumanRecommendCategoryTag.where(category_id: @default_category.id).limit(40)
    
    @album_list = Album.shard(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1) if @current_uid

    #容量限制
    if @current_user.isRobot or @current_user.isVerified  #机器人没有容量限制
      @progress = 0
      @capacity_free = nil
    else
      default_capacity = Settings.capacity_free
      used_capacity = $stat_user_track_client.getUserTotalTime(@current_uid)
      @progress = used_capacity<=default_capacity ? (used_capacity.to_f/default_capacity)*100 : 100
      @capacity_free = (tmp = ((default_capacity - used_capacity)/60).ceil)>0 ? tmp : 0
    end

    @checkCaptcha = true
    if !@current_user.isVerified and !@current_user.isVMobile
      @checkCaptcha = $wordfilter_client.checkCaptcha(2, @current_uid, get_client_ip);
    end

    @this_title = "上传声音 喜马拉雅-听我想听"

    erb :upload_page
  end

  #选择已有专辑
  def get_album_choose_list_partial

    set_no_cache_header

    halt_400 unless @current_uid

    @page = (tmp=params[:page].to_i)>0 ? tmp : 1
    @per_page = 12

    all_albums = Album.shard(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1)
    @albums_count = all_albums.count
    @albums = all_albums.order("id desc").offset((@page-1)*@per_page).limit(@per_page)

    erb(:_upload_album_choose_list_partial,layout:false)
  end

  #验证码图片src
  def get_valid_code_partial
    set_no_cache_header
    erb(:_valid_code_partial,layout:false)
  end

  def get_valid_code_json
    set_no_cache_header
    
    codeid = SecureRandom.uuid

    img_src = File.join(Settings.check_outer_root, "/getcode?codeId=#{codeid}")
    render_json({codeid:codeid,img_src:img_src})
  end

  #编辑声音 action
  def do_update_track

    halt_400 unless @current_uid

    #判断图片是否全部上传完成
    images = Array.wrap(params[:image].presence).take(4)
    images.each do |img|
      halt render_json({res: false, errors: [['page', '图片正在上传中，请稍侯']]}) if img.blank?
    end

    record = TrackRecord.shard(@current_uid).where(uid: @current_uid, id: params[:id], is_deleted: false).first
    halt_error("声音已删除或者不存在") unless record or record.op_type != TrackRecordTemp::OP_TYPE[:UPLOAD]

    track = Track.shard(record.track_id).where(id: record.track_id, is_deleted: false).first
    halt_error("声音源数据不存在") unless track

    if Settings.is_check_mobile
      halt render_json({res: false, errors: [['mobile', '请先绑定手机']]}) unless @current_user.mobile
    end

    #参数整理
    title = params[:title].to_s.chomp
    intro = params[:intro].to_s
    rich_intro = params[:rich_intro].to_s
    is_public = params[:is_public].to_s!="0"
    album_id = (tmp=params[:album_id].to_i)>0 && tmp
    destroy_images = params[:destroy_images].to_s.split(",")
    music_category = params[:categories_music]
    singer = params[:singer].to_s
    singer_category = params[:singer_category].to_s
    author = params[:author].to_s
    composer = params[:composer].to_s
    arrangement = params[:arrangement].to_s
    post_production = params[:post_production].to_s
    lyric = params[:lyric].to_s
    resinger = params[:resinger].to_s
    announcer = params[:announcer].to_s
    
    catch_errors = catch_upload_basic_errors(title, 1, 1, intro, '')
    halt render_json({res: false, errors: catch_errors}) if catch_errors.size > 0
    
    # 声音信息敏感词验证
    track_dirts = filter_hash(2, @current_user, get_client_ip, {
      title: title,
      intro: intro,
      lyric: lyric,
      singer: singer,
      singer_category: singer_category,
      author: author,
      composer: composer,
      arrangement: arrangement,
      post_production: post_production,
      lyric: lyric,
      resinger: resinger,
      announcer: announcer
    })
    halt render_json({res: false, errors: [['dirty_words', track_dirts]]}) if track_dirts.size > 0

    if album_id
      album = TrackSet.shard(album_id).where(uid: @current_uid, id: album_id, is_deleted: false).first
      if album and track.album_id != album.id
        album_track_count = TrackRecord.shard(@current_uid).where(uid: @current_uid, album_id: album.id, is_deleted: false, status: [0,1]).count
        delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count
        temp_track_count = TempAlbumForm.where(uid: @current_uid, state: 0, album_id: album.id).sum('add_tracks') # 专辑缓存表中的数据也算上
        allcount = album_track_count + delayed_track_count + temp_track_count + 1
        halt render_json({res: false, errors: [['add_to_album', '专辑声音数已满']]}) if allcount > 200
      end
    end

    update_single_track(track,record,album,title,intro,is_public,rich_intro,lyric,singer,singer_category,author,composer,arrangement,post_production,resinger,announcer,music_category,images,destroy_images)

    halt render_json({res: true, redirect_to: "/#{@current_uid}/sound/"})
  end

  #上传声音 action  包括单个声音[可选 添加进专辑], 多个声音·创建专辑, 多个声音·选择专辑
  def do_dispatch_upload

    halt_400 unless @current_uid
    
    halt_403({res: false, errors: [['page', '对不起，您已被暂时禁止发布声音']]}) if @current_user.isLoginBan or is_user_banned?(@current_uid)

    if Settings.is_check_mobile
      halt render_json({res: false, errors: [['mobile', '请先绑定手机']]}) unless @current_user.mobile
    end

    if params[:codeid] and !@current_user.isVerified
      if Net::HTTP.get(URI(File.join(Settings.check_root, "/validateAction?codeId=#{params[:codeid]}&userCode=#{CGI.escape(params[:validcode] || '')}"))) == 'false'
        halt render_json({res: false, errors: [['page', '验证码不匹配']]})
      else
        $wordfilter_client.clearCaptcha(2, @current_uid, get_client_ip);
      end
    end

    if params[:is_album].to_s=='true'
      if (album_id=params[:choose_album]).present?
        upload_choose_album_action(album_id)
      else
        upload_create_album_action
      end
    else
      upload_create_track_action
    end
  end

  private

  def upload_create_track_action

    #判断图片是否全部上传完成
    images = Array.wrap(params[:image].presence).take(4)
    images.each do |img|
      halt render_json({res: false, errors: [['page', '图片正在上传中，请稍侯']]}) if img.blank?
    end

    fileid = Array.wrap(params[:fileids]).select{|fid| !%w(r m).include?(fid[0]) }.first
    halt render_json({res: false, errors: [['page', '数据不正确']]}) if fileid.blank?

    #参数整理
    title, user_source = params[:title].to_s.chomp, params[:user_source].to_i, 
    category_id = params[:categories].to_i
    tags = params[:tags].to_s.chomp.squeeze(" ")
    intro, rich_intro = params[:intro].to_s, params[:rich_intro].to_s
    music_category = params[:categories_music]
    singer = params[:singer].to_s
    singer_category = params[:singer_category].to_s
    author = params[:author].to_s
    composer = params[:composer].to_s
    arrangement = params[:arrangement].to_s
    post_production = params[:post_production].to_s
    lyric = params[:lyric].to_s
    resinger = params[:resinger].to_s
    announcer = params[:announcer].to_s
    is_public = params[:is_public].to_s!='0'
    sharing_to = params[:sharing_to]
    share_content = params[:share_content]
    album_id = (tmp=params[:album_id].to_i)>0 && tmp

    # 为空验证
    catch_errors = catch_upload_basic_errors(title, user_source, category_id, intro, tags)
    halt render_json({res: false, errors: catch_errors}) if catch_errors.size > 0

    # 声音信息敏感词验证
    track_dirts = filter_hash(2, @current_user, get_client_ip, {
      title: title,
      intro: intro,
      tags: tags,
      singer: singer,
      singer_category: singer_category,
      author: author,
      composer: composer,
      arrangement: arrangement,
      post_production: post_production,
      lyric: lyric,
      resinger: resinger,
      announcer: announcer
    }, true)
    return render_json({res: false, errors: [['dirty_words', track_dirts]]}) if track_dirts.size > 0

    if is_public and album_id
      album = TrackSet.shard(album_id).where(uid: @current_uid, id: album_id, is_deleted: false).first
      halt render_json({res: false, errors: [['page', '所选专辑已删除或者不存在']]}) if album.nil?
      album_track_count = TrackRecord.shard(@current_uid).where(uid: @current_uid, album_id: params[:album_id], is_deleted: false, status: [0,1]).count
      delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count
      temp_track_count = TempAlbumForm.where(uid: @current_uid, state: 0, album_id: album.id).sum('add_tracks')
      allcount = album_track_count + delayed_track_count + temp_track_count
      halt render_json({res: false, errors: [['add_to_album', '专辑声音数已满']]}) if allcount >= 200
    end

    # 检查新上传的声音转码状态
    transcode_res = TRANSCODE_SERVICE.checkTranscodeState(@current_uid, [Hessian2::TypeWrapper.new(:long, fileid)] )
    begin
      p_transcode_res = oj_load(transcode_res)
    rescue
      #
    end
    if p_transcode_res.nil? || !p_transcode_res['success']
      writelog('check transcode state failed')
      halt_error('声音转码失败')
    else
      transcode_data = p_transcode_res['data'][0]
    end

    # 定时上传
    if params[:is_publish] == 'on' and @current_user.isVerified
      if params[:date] and params[:hour] and params[:minutes]
        begin
          year,month,day = params[:date].to_s.split("-")
          datetime = Time.new(year,month,day,params[:hour],params[:minutes]).strftime('%Y-%m-%d %H:%M:%S')
        rescue
          writelog('analysis delay tasks datetime failed')
        end
        if datetime
          delayed_tasks_count = DelayedTrack.where(uid: @current_uid, is_deleted:false).group(:task_count_tag).to_a.size
          halt render_json({res: false, errors: [['publish', '定时发布任务不能超过10条']]}) if delayed_tasks_count >= 10

          delayed_upload_single_track(datetime,fileid,transcode_data,title,user_source,category_id,is_public,images,intro,rich_intro,tags,music_category,singer,singer_category,author,composer,arrangement,post_production,lyric,resinger,announcer,sharing_to,share_content,album)
          halt render_json({res: true, redirect_to: "/#/#{@current_uid}/publish/"})
        end
      end
    end

    upload_single_track(fileid,transcode_data,title,user_source,category_id,is_public,images,intro,rich_intro,tags,music_category,singer,singer_category,author,composer,arrangement,post_production,lyric,resinger,announcer,sharing_to,share_content,album)

    render_json({res: true, redirect_to: "/#/#{@current_uid}/sound/"})
  end

  def upload_create_album_action

    files = Array.wrap(params[:files]).take(200)
    fileids = Array.wrap(params[:fileids]).take(200)
    halt render_json({res: false, errors: [['page', '数据不正确']]}) if files.length != fileids.length

    #参数整理
    title, user_source = params[:title].to_s.chomp, params[:user_source].to_i, 
    category_id = params[:categories].to_i
    tags = params[:tags].to_s.chomp.squeeze(" ")
    intro, rich_intro = params[:intro].to_s, params[:rich_intro].to_s
    is_records_desc = params[:is_records_desc]=='on'
    is_finished, image = params[:is_finished].to_i, params[:image].to_s
    music_category = params[:categories_music]
    sharing_to = params[:sharing_to]
    share_content = params[:share_content]

    # 为空验证
    catch_errors = catch_upload_basic_errors(title, user_source, category_id, intro, tags)
    halt render_json({res: false, errors: catch_errors}) if catch_errors.size > 0

    new_fileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }
    new_fileids_size = new_fileids.size
    halt render_json({res: false, errors: [['page', '哎呀，专辑已经塞满啦']]}) if new_fileids_size > 50

    if new_fileids_size>0 # 检查新上传的声音转码状态
      transcode_res = TRANSCODE_SERVICE.checkTranscodeState(@current_uid, new_fileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
      p_transcode_res = oj_load(transcode_res)

      if !p_transcode_res['success']
        writelog('check transcode state failed')
        halt_error('声音转码失败')
      end
    end

    if image.present?
      begin
        img_data = oj_load(image)
        if img_data and img_data['status']
          pic = img_data['data'][0]['processResult']
          default_cover_path = pic['origin']
          default_cover_exlore_height = pic['180n_height']
        end
      rescue
        #
      end
    end

    # 专辑信息敏感词验证
    album_dirts = filter_hash( 2, @current_user, get_client_ip, {title:title,intro:intro,tags:tags} )
    halt render_json({res: false, errors: [['files_dirty_words', album_dirts]]}) if album_dirts.size > 0

    # 声音信息敏感词验证
    words = {}
    fileids.each_with_index do |fileid, i|
      words[fileid.to_s] = files[i]
    end
    if words.size > 0
      files_dirts = filter_hash(2, @current_user, get_client_ip, words, new_fileids_size > 0)
      halt render_json({res: false, errors: [['files_dirty_words', files_dirts]]}) if files_dirts.size > 0
    end

    zipfiles = fileids.zip(files)

    # 定时上传
    if params[:is_publish] == 'on' and @current_user.isVerified
      if params[:date] and params[:hour] and params[:minutes]
        begin
          year,month,day = params[:date].to_s.split("-")
          datetime = Time.new(year,month,day,params[:hour],params[:minutes]).strftime('%Y-%m-%d %H:%M:%S')
        rescue
          writelog('analysis delay tasks datetime failed')
        end
        if datetime
          delayed_tasks_count = DelayedTrack.where(uid: @current_uid, is_deleted:false).group(:task_count_tag).to_a.size
          halt render_json({res: false, errors: [['publish', '定时发布任务不能超过10条']]}) if delayed_tasks_count >= 10

          delayed_create_album_and_tracks(datetime,zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
          halt render_json({res: true, redirect_to: "/#/#{@current_uid}/publish/"})
        end
      end
    end

    create_album_and_tracks(zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
    halt render_json({res: true, redirect_to: "/#/#{@current_uid}/album"})
  end

  def upload_choose_album_action(album_id)
    album = TrackSet.shard(album_id).where(uid: @current_uid, id: album_id, is_deleted: false).first
    halt render_json({res: false, errors: [['page', '抱歉,无法添加到该专辑']]}) unless album
    
    files = Array.wrap(params[:files]).take(200)
    fileids = Array.wrap(params[:fileids]).take(200)
    halt render_json({res: false, errors: [['page', '数据不正确']]}) if files.length != fileids.length
    
    is_records_desc = params[:is_records_desc]=='on'
    sharing_to = params[:sharing_to]
    share_content = params[:share_content]

    new_fileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }
    new_fileids_size = new_fileids.size
    halt_403({res: false, errors: [['page', '对不起，您已被暂时禁止发布声音']]}) if new_fileids_size>0 and ( @current_user.isLoginBan or is_user_banned?(@current_uid) )

    album_track_count = TrackRecord.shard(@current_uid).where(uid: @current_uid, album_id: album.id, is_deleted: false, status: [0,1]).count
    delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count
    temp_track_count = TempAlbumForm.where(uid: @current_uid, state: 0, album_id: album.id).sum('add_tracks') # 专辑缓存表中的数据也算上
    allcount = delayed_track_count + new_fileids_size + album_track_count + temp_track_count
    halt render_json({res: false, errors: [['page', '哎呀，专辑已经塞满啦']]}) if new_fileids_size > 50 or (allcount >= 200 and new_fileids_size > 0)

    # 声音信息敏感词验证
    words = {}
    fileids.each_with_index {|fileid, i| words[fileid.to_s] = files[i] }
    if words.size > 0
      files_dirts = filter_hash(2, @current_user, get_client_ip, words, new_fileids_size > 0)
      halt render_json({res: false, errors: [['files_dirty_words', files_dirts]]}) if files_dirts.size > 0
    end

    if new_fileids_size>0
      transcode_res = TRANSCODE_SERVICE.checkTranscodeState(@current_uid, new_fileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
      p_transcode_res = oj_load(transcode_res)

      if !p_transcode_res['success']
        writelog('check transcode state failed')
        halt_error('声音转码失败')
      end

      if album.cover_path  # 把专辑封面用作声音默认封面
        pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
        default_cover_path = pic['origin']
        default_cover_exlore_height = pic['180n_height']
      end

      #定时上传配置
      if params[:is_publish]=='on' and @current_user.isVerified
        if params[:date] and params[:hour] and params[:minutes]
          begin
            year,month,day = params[:date].to_s.split("-")
            datetime = Time.new(year,month,day,params[:hour],params[:minutes]).strftime('%Y-%m-%d %H:%M:%S')
          rescue
            writelog('analysis delay tasks datetime failed')
          end
          if datetime
            delayed_tasks_count = DelayedTrack.where(uid: @current_uid, is_deleted:false).group(:task_count_tag).to_a.size
            halt render_json({res: false, errors: [['publish', '定时发布任务不能超过10条']]}) if delayed_tasks_count >= 10
            rdt_url = "/#/#{@current_uid}/publish/"
          end
        end
      end

    end

    zipfiles = fileids.zip(files)
    upload_tracks_into_album(album,zipfiles,is_records_desc,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height,datetime)
    rdt_url ||= "/#/#{@current_uid}/album/"

    halt render_json({res: true, redirect_to: rdt_url})
  end


end