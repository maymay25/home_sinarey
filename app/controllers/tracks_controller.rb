class TracksController < ApplicationController

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

    @tir = TrackInRecord.fetch(params[:id])

    halt_404 if @tir.nil? or @tir.is_deleted

    is_own = @tir.uid == @current_uid

    if @tir.is_public
      return halt_status0 if @tir.status == 0 && !is_own
      return halt_status2 if @tir.status == 2
    else
      return halt_404 if !is_own
    end

    # 是否已收藏
    @is_favorited = @current_uid ? Favorite.stn(@current_uid).where(uid: @current_uid, track_id: @tir.id).any? : false

    # 声音相关计数
    @comments_count, @favorites_count, @plays_count, @shares_count = $counter_client.getByNames([
        Settings.counter.track.comments,
        Settings.counter.track.favorites,
        Settings.counter.track.plays,
        Settings.counter.track.shares
      ], @tir.track_id)

    @category_name,@category_title = nil,nil
    if @tir.category_id
      category = Category.where(id: @tir.category_id).first
      if category
        @category_name = category.name 
        @category_title = category.title
      end
    end

    @track_user = $profile_client.queryUserBasicInfo(@tir.track_uid)

    check_follow_status(@track_user.uid)

    set_no_cache_header
    @this_title = "#{@tir.title} 喜马拉雅-听我想听"

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

    @u = $profile_client.queryUserBasicInfo(@tir.uid)

    @track_record = TrackRecord.stn(@tir.uid).where(uid: @tir.uid, track_id: @tir.track_id, is_deleted: false).first
    @track_rich = TrackRich.stn(@tir.track_id).where(track_id: @tir.track_id).first

    @all_track_records = TrackInRecord.stn(@tir.track_id).where("album_id is not null and track_id = ?", @tir.track_id).limit(6)

    @is_favorited = @current_uid ? Favorite.stn(@current_uid).where(uid: @current_uid, track_id: @tir.track_id).any? : false

    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    all_lover = Lover.stn(@tir.track_id).where(track_id: @tir.track_id)

    @lovers_count = all_lover.count
    lovers = all_lover.select('id, uid').order("created_at desc").offset((@page-1)*@per_page).limit(@per_page)
    lover_uids = lovers.collect{|l| l.uid}
    if lover_uids.size > 0
      profile_users = $profile_client.getMultiUserBasicInfos(lover_uids)
      @lovers = lover_uids.collect{ |uid| profile_users[uid] }
      @lover_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, lover_uids)
      @lover_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, lover_uids)
    else
      @lovers = []
      @lover_tracks_counts = []
      @lover_followers_counts = []
    end

    @track_play_count = $counter_client.get(Settings.counter.track.plays, @tir.track_id.to_s)
    @track_share_count = $counter_client.get(Settings.counter.track.shares, @tir.track_id.to_s)
    @track_comment_count = Comment.stn(@tir.track_id).where(track_id: @tir.track_id).count
    @track_favorite_count = Lover.stn(@tir.track_id).where(track_id: @tir.track_id).count

    # 计数纠正
    comment_counter = $counter_client.get(Settings.counter.track.comments, @tir.track_id.to_s)
    lovers_counter = $counter_client.get(Settings.counter.track.favorites, @tir.track_id.to_s)
    if comment_counter != @track_comment_count
      $counter_client.set(Settings.counter.track.comments, @tir.track_id, @track_comment_count)
    end
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

    tir = TrackInRecord.fetch(params[:track_id])
    halt render_json({res: false, message: "", msg: '该声音不存在'}) if tir.nil? or tir.is_deleted

    halt render_json({res: false, message: "", msg: '抱歉，该声音正在审核中'}) if tir.status == 0

    halt render_json({res: false, message: "", msg: '该声音已经下架'}) if tir.status != 1

    halt render_json({res: false, message: "", msg: '私密声音不能赞'}) unless tir.is_public

    #黑名单
    halt render_json({res: false, message: "", msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid: tir.uid, black_uid: @current_uid).first

    unless Favorite.stn(@current_uid).where(uid: @current_uid, track_id: tir.track_id).any?
      fav = Favorite.create(uid: @current_uid,
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic, 
        track_id: tir.track_id,
        track_uid: tir.uid,
        track_upload_source: tir.upload_source,
        is_v: tir.is_v,
        upload_source: 2,
        waveform: tir.waveform,
        upload_id: tir.upload_id
      )

      topic_hash = fav.to_topic_hash
      current_ps = PersonalSetting.where(uid: @current_uid).first
      topic_hash[:is_feed] = current_ps.nil? || current_ps.is_feed_favorite==true

      $rabbitmq_channel.fanout(Settings.topic.favorite.created, durable: true).publish(Yajl::Encoder.encode(topic_hash), content_type: 'text/plain', persistent: true)

      $rabbitmq_channel.queue('favorite.created.dj', durable: true).publish(Yajl::Encoder.encode({
        uid: fav.uid,
        id: fav.id,
        sharing_to: params[:sharing_to],
        dotcom: Settings.home_root,
        is_mob: false,
        upload_source: 2
      }), content_type: 'text/plain')

      $counter_client.incr(Settings.counter.user.favorites, @current_uid, 1)

      $counter_client.incr(Settings.counter.track.favorites, fav.track_id, 1)

      # 同步分享确认, 不再提示
      if params[:no_more_alert] and !params[:no_more_alert].empty?
        $sync_set_client.noMoreFavoriteSyncAlert(@current_uid, params[:no_more_alert]=='true')
      end

    end

    halt render_json({res: true, msg: print_message(:success)})
  end

  #取消赞声音
  def cancel_like_track

    halt_400 unless @current_uid

    fav = Favorite.stn(@current_uid).where(uid: @current_uid, track_id: params[:track_id]).first
    if fav
      fav.destroy

      # 发已删除topic
      $rabbitmq_channel.fanout(Settings.topic.favorite.destroyed, durable: true).publish(Yajl::Encoder.encode({
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

    halt '' unless params[:id]

    now = Time.new
    uuid = SecureRandom.uuid.gsub('-', '')
    rk = "#{now.to_i}_#{params[:id]}_#{uuid}"
    if @current_user
      is_v = @current_user.isVerified
      if @current_user.thirdpartyName
        tpname = @current_user.thirdpartyName['name']
      end
    end

    $counter_client.incr(Settings.counter.track.plays, params[:id].to_i, 1) # 同步加播放数
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
      started_at: now,
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

    track = Track.stn(params[:id]).where(id: params[:id]).first
    halt render_json({res:false, error:"failure", msg:"声音不存在或者已经被删除"}) if track.nil? or track.is_deleted

    # 自己的声音不能转发
    halt render_json({res:false, error:"failure", msg:"自己的声音不能转发"}) if track.uid == @current_uid

    halt render_json({res:false, error:"failure", msg:"抱歉，该声音正在审核中"}) if track.status == 0

    halt render_json({res:false, error:"failure", msg:"该声音已经下架"}) if track.status != 1

    halt render_json({res: false, message: "", msg: '私密声音不能转发'}) unless track.is_public

    # 只能转发一次
    my_trackrecords_count = TrackRecord.stn(@current_uid).where(uid: @current_uid, track_id: track.id, is_public: true, is_deleted: false, status: 1).count
    halt render_json({res: false, error: 2,msg: "你已经转采了该声音"}) if my_trackrecords_count > 0

    #黑名单
    halt render_json({res: false, message: "", msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid: track.uid,black_uid:@current_uid).first

    if !params[:content].nil? && !params[:content].empty?
      res = $wordfilter_client.wordFilters(5, @current_uid, get_client_ip, params[:content])
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
      track_upload_source: track.upload_source,
      uid: @current_uid,  # RECORD拥有者
      nickname: @current_user.nickname,
      is_v: @current_user.isVerified,
      dig_status: @current_user.isVerified ? 1 : 0,
      human_category_id: @current_user.vCategoryId,
      approved_at: Time.now,
      avatar_path: @current_user.logoPic,
      op_type: TrackRecordOrigin::OP_TYPE[:RELAY],
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
      lyric: track.lyric,
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
      comment_content: "",  # 异步添加值
      comment_id: nil,  # 异步添加值
      waveform: track.waveform,
      upload_id:track.upload_id,
      status: 1
    }
    record = TrackRecord.create(record_hash)

    #同步到Origin表
    record_origin = TrackRecordOrigin.new
    record_origin.id = record.id
    record_origin.created_at = record.created_at
    record_origin.updated_at = record.updated_at
    record_origin.update_attributes(record_hash)

    # 异步处理转发事件
    sharing_to = params[:sharing_to]

    # 生成转发topic
    share_content = params[:content] ? cut_str(params[:content].strip, 60, '..') : ''
    
    $rabbitmq_channel.fanout(Settings.topic.track.relay, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge({
      id: record.id,
      content: params[:content], 
      sharing_to: sharing_to, 
      relay_uid: @current_uid, 
      relay_nickname: @current_user.nickname, 
      relay_avatar_path: @current_user.logoPic, 
      relay_content: share_content, 
      track_id: track.id, 
      track_record_id: record.id,
      upload_source: 2, 
      human_category_id: @current_user.vCategoryId,
      created_at: Time.now
    })), content_type: 'text/plain', persistent: true)

    # 声音的转发数  +1
    $counter_client.incr(Settings.counter.track.shares, track.id, 1)

    halt render_json({ res: true })
  end

  # 私密声音转公开
  def do_set_public

    halt_400 unless @current_uid

    halt render_json({res: false}) unless params[:record_id]

    record = TrackRecord.stn(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false).first
    halt render_json({res: false}) unless record

    track = Track.stn(record.track_id).where(id: record.track_id, is_deleted: false).first
    halt render_json({res: false}) if track.nil? or track.uid != @current_uid or track.is_public

    record.update_attribute('is_public', true)
    track.update_attribute('is_public', true)
    $rabbitmq_channel.fanout(Settings.topic.track.created, durable: true).publish(Yajl::Encoder.encode(track.to_topic_hash.merge(user_agent: request.user_agent, is_feed: true)), content_type: 'text/plain', persistent: true)
    bunny_logger ||= ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
    bunny_logger.info "track.created.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"

    $rabbitmq_channel.queue('track.on', durable: true).publish(Yajl::Encoder.encode({id: track.id, is_new: true}), content_type: 'text/plain')

    halt render_json({res: true, message: '改动已生效'})
  end

  def get_album_list

    set_no_cache_header

    list = []
    albums = Album.stn(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1)
    albums.each do |album|
      list << {id: album.id, title: CGI::escapeHTML(album.title ? album.title[0..30] : '')}
    end

    halt render_json({response: list})
  end

  # 添加到专辑
  def do_join_album

    halt render_json({res: false, error: "failure"}) unless @current_uid
    
    halt render_json({res: false, error: "failure"}) unless params[:record_id]

    record = TrackRecord.stn(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false, status: 1).first
    halt render_json({res: false, error: "failure"}) unless record
    
    old_album_id = record.album_id
    track = Track.stn(record.track_id).where(id: record.track_id, is_public: true, is_deleted: false, status: 1).first if record
    halt render_json({res: false,  error: 'track not exsit'}) unless track

    if params[:album_id] # 选择已存在的专辑
      count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: params[:album_id], is_public: true, is_deleted: false, status: 1).count
      halt render_json({res: false, error: "album_full"}) if count >= 200

      album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:album_id], is_deleted: false, status: 1).first
      halt render_json({res: false, error: "failure"}) if album.nil?

      unless album.id == old_album_id
        track.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path) if record.op_type == 1
        record.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path)

        # 将该声音添加到新专辑的声音序列
        update_attrs = {}
        if album.tracks_order
          if album.is_records_desc
            _tracks_order = ( [params[:record_id]] + album.tracks_order.split(",") ).join(",")
          else
            _tracks_order = album.tracks_order.split(",").push(params[:record_id]).join(",")
          end
          update_attrs[:tracks_order] = _tracks_order
        end
        album.update_attributes(update_attrs) unless update_attrs == {}

        # old_album_id 旧专辑的最后声音的更新操作在album.updated.dj里完成
        $rabbitmq_channel.queue('album.updated.dj', durable: true).publish(Yajl::Encoder.encode({
          id: album.id,
          is_new: false,
          created_record_ids: [],
          updated_track_ids: [],
          moved_record_id_old_album_ids: [ [record.id, old_album_id] ],
          destroyed_track_ids: [],
          user_agent: request.user_agent
        }), content_type: 'text/plain')
      end
    elsif params[:album_title] and !params[:album_title].strip.empty?
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
      album.dig_status = @current_user.isVerified ? 1 : 0
      album.human_category_id = @current_user.vCategoryId
      album.category_id = track.category_id
      album.tags = track.tags
      album.cover_path = track.cover_path
      album.user_source = track.user_source
      album.is_publish = true
      album.is_public = true
      album.status = get_default_status(@current_user)
      album.tracks_order = params[:record_id]
      album.save

      track.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path) if record.op_type == 1
      record.update_attributes(album_id: album.id, album_title: album.title, album_cover_path: album.cover_path)

      $rabbitmq_channel.queue('album.updated.dj', durable: true).publish(Yajl::Encoder.encode({
        id: album.id,
        is_new: true,
        created_record_ids: [],
        updated_track_ids: [],
        moved_record_id_old_album_ids: [ [record.id, old_album_id] ],
        destroyed_track_ids: [],
        user_agent: request.user_agent
      }), content_type: 'text/plain')
    end

    halt render_json({res: true, id: album.id, title: CGI::escapeHTML(album.title)})
  end

  # 删除声音
  def do_destroy_track

    halt_400 unless @current_uid

    record = TrackRecord.stn(@current_uid).where(uid: @current_uid, id: params[:record_id], is_deleted: false).first
    halt render_json({res: false, msg: "该声音已删除"}) unless record

    record.update_attribute(:is_deleted,true)

    if record.album_id
      album = Album.stn(@current_uid).where(uid: @current_uid, id: record.album_id, is_deleted: false).first
      #更新专辑的声音排序   #维护专辑的'最后更新声音'(在异步脚本中实现)
      if album
        if album.tracks_order
          this_tracks_order = album.tracks_order.split(",").delete_if{ |record_id| "#{record_id}" == "#{params[:record_id]}" }.join(",")
          album.tracks_order = this_tracks_order
        end
        album.save
      end
    end

    if record.op_type == TrackRecordOrigin::OP_TYPE[:UPLOAD]
      track = Track.stn(record.track_id).where(id: record.track_id, is_deleted: false).first
      if track
        old_is_deleted = track.is_deleted
        track.update_attribute(:is_deleted, true)
        topic = track.to_topic_hash.merge(is_feed: true, is_off: (!old_is_deleted && track.is_public && track.status == 1))
        $rabbitmq_channel.fanout(Settings.topic.track.destroyed, durable: true).publish(Oj.dump(topic, mode: :compat), content_type: 'text/plain', persistent: true)
        bunny_logger ||= ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
        bunny_logger.info "track.destroyed.topic #{track.id} #{track.title} #{track.nickname} #{track.updated_at.strftime('%R')}"
      end
    elsif record.op_type == TrackRecordOrigin::OP_TYPE[:RELAY]
      $counter_client.decr(Settings.counter.user.tracks, record.uid, 1)
      $counter_client.decr(Settings.counter.track.shares, record.track_id, 1)

      # 转采的声音 所在专辑的声音数 -1
      if record.album_id
        $counter_client.decr(Settings.counter.album.tracks, record.album_id, 1)
      end

      $rabbitmq_channel.fanout(Settings.topic.track.relay_destroyed, durable: true).publish(Yajl::Encoder.encode({
        id: record.id, track_id: record.track_id, uid: record.uid, created_at: record.created_at, is_feed: true
      }), content_type: 'text/plain', persistent: true)
    end

    halt render_json({res: true, msg: print_message(:success)})
  end

  # 评论列表
  def track_comment_list_template
    set_no_cache_header
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

    @tir = TrackInRecord.fetch(params[:id])
    halt '' if @tir.nil? or @tir.is_deleted or @tir.status != 1
    @comments_count = Comment.stn(@tir.track_id).where(track_id: @tir.track_id).count
    @comments = Comment.stn(@tir.track_id).where(track_id: @tir.track_id).order('created_at desc').limit(10)
    render_to_string(partial: :_feed_comment_list)
  end

  ##ajax 该声音被这些人转采(feed列表)
  def feed_relay_list_template

    set_no_cache_header

    @tir = TrackInRecord.fetch(params[:id])
    halt '' if @tir.nil? or @tir.is_deleted or @tir.status != 1
    @relays_count = TrackInRecord.stn(@tir.track_id).where(track_id: @tir.track_id, op_type: 2).count
    @relays = TrackInRecord.stn(@tir.track_id).where(track_id: @tir.track_id, op_type: 2).order("created_at desc").limit(10)
    render_to_string(partial: :_feed_relay_list)
  end

  # 你可能还喜欢
  def maybe_like_list_template

    set_no_cache_header

    tir = TrackInRecord.fetch(params[:id])
    halt '' if tir.nil? or tir.is_deleted or tir.status != 1

    render_to_string(partial: :_maybe_like_list, locals: { category_id: tir.category_id || 0 })
  end

  # 右侧 他的其它声音，广告，收录专辑，喜欢该声音的人，扫一扫
  def right_template

    set_no_cache_header

    tir = TrackInRecord.fetch(params[:id])
    halt '' if tir.nil? or tir.is_deleted or tir.status != 1
    
    render_to_string(partial: :_right, locals: {tir: tir})
  end

  # 声音详细展开
  def rich_intro_template

    set_no_cache_header

    @tir = TrackInRecord.fetch(params[:id])
    halt '' if @tir.nil? or @tir.is_deleted or @tir.status != 1
    
    render_to_string(partial: :_rich_intro)
  end

  # 声音列表，ajax载入播放器片段，主要处理没有波形的情况
  def expend_box_template

    set_no_cache_header

    @tir = TrackInRecord.fetch(params[:id])
    halt '' if @tir.nil? or @tir.is_deleted or @tir.status != 1

    # 是否已收藏
    @is_favorited = @current_uid && Favorite.stn(@current_uid).where(uid: @current_uid, track_id: @tir.track_id).any?

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
    
    track_pictures = TrackPicture.stn(track_id).where(track_id:track_id).order("order_num asc")
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
      tb = TrackBlock.stn(track_id).where(track_id: track_id).first
      halt '' unless tb

      bash = {}
      BlockAvatar.stn(track_id).where(track_id: track_id).select('block_id, avatar_path, created_at').order('created_at desc').each do |ba|
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
    tb = TrackBlock.stn(params[:track_id]).where(track_id: params[:track_id]).first

    halt render_json({ count: 0, comments: nil, msg: print_message(:record_not_found, "track_id: #{params[:track_id]}") }) unless tb

    halt render_json({ count: 0, comments: nil,msg: print_message(:validation_failed, "index: #{block_idx}, track blocks: #{tb.blocks}") }) if block_idx > tb.blocks

    comments_count = tb.send("b#{block_idx}")

    comments = Comment.stn(tb.track_id).where(track_id: tb.track_id, block: block_idx).order('created_at desc').limit(Settings.per_page.track_block_comments).select('content, created_at, id, nickname, avatar_path, parent_id, second, track_id, uid')

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
    tir = TrackInRecord.fetch(params[:id])
    halt '' if tir.nil? or (!tir.is_public && tir.track_uid != @current_uid) or tir.is_deleted or tir.status == 2 or (tir.status == 0 && tir.track_uid != @current_uid)

    uid = @current_uid || params[:uid]

    category_name, category_title = CATEGORIES[tir.category_id]

    play_count, comments_count, shares_count, favorites_count = $counter_client.getByNames([
        Settings.counter.track.plays,
        Settings.counter.track.comments,
        Settings.counter.track.shares,
        Settings.counter.track.favorites
      ], tir.track_id)

    tir_hash = {
      id: tir.track_id,
      play_path_64: tir.play_path_64,
      play_path_32: tir.play_path_32,
      play_path_128: tir.play_path_128,
      play_path: tir.play_path,
      duration: tir.duration,
      title: tir.title,
      nickname: tir.nickname,
      uid: tir.uid,
      waveform: tir.waveform,
      upload_id: tir.upload_id,
      cover_url: file_url(tir.cover_path),
      cover_url_142: picture_url('track', tir.cover_path, '180'),
      formatted_created_at: tir.created_at.strftime('%-m月%-d日 %H:%M'),
      is_favorited: nil,
      play_count: play_count,
      comments_count: comments_count,
      shares_count: shares_count,
      favorites_count: favorites_count,
      title: tir.title ? CGI::escapeHTML(tir.title) : '',
      album_title: tir.album_title ? CGI::escapeHTML(tir.album_title) : '',
      intro: tir.intro ? CGI::escapeHTML(tir.intro) : '',
      short_intro: tir.short_intro ? CGI::escapeHTML(tir.short_intro) : '',
      have_more_intro: tir.intro ? tir.intro.length > 100 : false,
      time_until_now: parse_time_until_now(tir.created_at),
      category_name: category_name,
      category_title: category_title,
      played_secs: nil
    }

    render_json(tir_hash)
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
          is_favorited: @current_uid ? Favorite.stn(@current_uid).where(uid: @current_uid, track_id: tir.track_id).any? : false,
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


end