class AlbumsController < ApplicationController

  include UploadsHelper

  set :views, ['albums','application']

  def dispatch(action,params_options={})
    params_options.each {|k,v| params[k] = v }
    super(:albums,action)
    method(action).call
  end

  def show_album_page

    redirect_to_root

    @album = TrackSet.fetch(params[:id])

    halt_404 if @album.nil? or @album.is_deleted

    is_own = @album.uid == @current_uid

    if @album.is_public
      halt_status0 if @album.status == 0 && !is_own
      halt_status2 if @album.status == 2
    else
      halt_404 if !is_own
    end

    @u = $profile_client.queryUserBasicInfo(@album.uid)
    
    setrich = TrackSetRich.stn(@album.id).where(track_set_id: @album.id).select('rich_intro').first
    @rich_intro = setrich ? clean_html(setrich.rich_intro) : clean_html(@album.intro)

    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 100

    tracks_conds = {uid: @album.uid, album_id: @album.id, is_deleted: false}
    if !is_own
      tracks_conds[:status] = 1
      tracks_conds[:is_public] = true
    else
      tracks_conds[:status] = [ 0, 1 ]
    end
    
    if params[:order] == 'created_at desc'
      order = 'created_at desc'
    elsif params[:order] == 'created_at asc'
      order = 'created_at asc'
    else
      if @album.is_crawler
        order = @album.is_records_desc ? 'order_num desc, created_at desc' : 'order_num, created_at'
      else
        if @album.tracks_order.nil? || @album.tracks_order.empty?
          order = 'created_at desc'
        else
          order = "field(id,#{@album.tracks_order})"
        end
      end
    end

    @all_tracks_count = TrackRecord.stn(@album.uid).where(tracks_conds).count

    @tracks = TrackRecord.stn(@album.uid).where(tracks_conds).order(order).offset((@page - 1) * @per_page).limit(@per_page)

    #专辑下的声音，每一个的播放计数都要
    track_ids = @tracks.collect{|r| r.track_id }
    if track_ids.length > 0
      @tracks_play_count = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
    end

    @plays_count = $counter_client.get(Settings.counter.album.plays, @album.id)

    if @tracks && @tracks[0] && @tracks[0].track_id
      @init_track_play_count = $counter_client.get(Settings.counter.track.plays, @tracks[0].track_id)
      @init_track_favorite_count = $counter_client.get(Settings.counter.track.favorites, @tracks[0].track_id)
      @init_track_share_count = $counter_client.get(Settings.counter.track.shares, @tracks[0].track_id)
      @init_track_comment_count = $counter_client.get(Settings.counter.track.comments, @tracks[0].track_id)
    end

    @category_name,@category_title = nil,nil
    if @album.category_id
      category = Category.where(id: @album.category_id).first
      if category
        @category_name = category.name
        @category_title = category.title
      end
    end
    
    check_follow_status(@album.uid)
    
    @this_title = "#{@album.title} 喜马拉雅-听我想听"

    halt erb_js(:show_js) if request.xhr?
    erb :show
  end

  def show_right

    halt_404 unless request.xhr?

    set_no_cache_header

    album_id = params[:id].to_i
    halt if album_id < 1

    album = TrackSet.fetch(album_id)
    halt unless album

    halt render_to_string(partial: :_right, locals: {album: album})
  end

  #创建专辑 表单页
  def new_album_page

    halt_404 if request.xhr?

    set_no_cache_header
    
    redirect_to_login('/new_album') unless @current_uid

    halt_403 if @current_user.isLoginBan or is_user_banned?(@current_uid)

    @list = TrackRecord.stn(@current_uid).where(uid: @current_uid, op_type: TrackRecordOrigin::OP_TYPE[:UPLOAD], album_id: nil, is_public: true, is_deleted: false).order('id desc')

    category_id = 1 #默认为 "其他"
    @user_tags = UserTag.stn(@current_uid).where(uid: @current_uid).order("num desc").limit(15)
    @tags = HumanRecommendCategoryTag.where("category_id = :category_id",{:category_id=>category_id})
    
    @checkCaptcha = true
    if !@current_user.isVerified and !@current_user.isVMobile
      @checkCaptcha = $wordfilter_client.checkCaptcha(2, @current_uid, get_client_ip);
    end

    if @current_user.isRobot or @current_user.isVerified
      @capacity_free = 999 #加V用户容量无限制
    else
      default_capacity = Settings.capacity_free
      used_capacity = $stat_user_track_client.getUserTotalTime(@current_uid)
      @capacity_free = default_capacity - used_capacity
    end

    @this_title = "创建专辑 喜马拉雅-听我想听"

    erb :new_album_page
  end

  #创建专辑 action
  def do_create_album

    halt_400 unless @current_uid

    halt_403({res: false, errors: [['page', '对不起，您已被暂时禁止发布专辑']]}) if @current_user.isLoginBan or is_user_banned?(@current_uid)

    if params[:codeid] and !@current_user.isVerified
      if Net::HTTP.get(URI(File.join(Settings.check_root, "/validateAction?codeId=#{params[:codeid]}&userCode=#{CGI.escape(params[:validcode] || '')}"))) == 'false'
        halt render_json({res: false, errors: [['page', '验证码不匹配']]})
      else
        $wordfilter_client.clearCaptcha(2, @current_uid, get_client_ip);
      end
    end

    files = Array.wrap(params[:files]).take(200)
    fileids = Array.wrap(params[:fileids]).take(200)
    halt render_json({res: false, errors: [['page', '数据不正确']]}) if files.length != fileids.length
    zipfiles = fileids.zip(files)

    #参数整理
    title, user_source = params[:title].to_s.chomp, params[:user_source].to_i, 
    category_id = params[:category_id].to_i
    tags = params[:tags].to_s.chomp.squeeze(" ")
    intro, rich_intro = params[:intro].to_s, params[:rich_intro].to_s
    is_records_desc = params[:is_records_desc]=='on'
    is_finished, image = params[:is_finished].to_i, params[:image].to_s
    music_category = params[:sub_category_id]
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
      p_transcode_res = Yajl::Parser.parse(transcode_res)
      if !p_transcode_res['success']
        writelog('check transcode state failed')
        halt_error('声音转码失败')
      end
    end

    # 专辑信息敏感词验证
    album_dirts = filter_hash( 2, @current_user, get_client_ip, {title:title,intro:intro,tags:tags} )
    halt render_json({res: false, errors: [['files_dirty_words', album_dirts]]}) if album_dirts.size > 0

    # 声音标题敏感词验证
    words = {}
    fileids.each_with_index{|fileid, i| words[fileid.to_s] = files[i] }
    if words.size > 0
      files_dirts = filter_hash(2, @current_user, get_client_ip, words, new_fileids_size > 0)
      halt render_json({res: false, errors: [['files_dirty_words', files_dirts]]}) if files_dirts.size > 0
    end

    if image.present?
      begin
        img_data = Yajl::Parser.parse(image)
        if img_data and img_data['status']
          pic = img_data['data'][0]['processResult']
          default_cover_path = pic['origin']
          default_cover_exlore_height = pic['180n_height']
        end
      rescue
        #
      end
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

          delayed_create_album_and_tracks(datetime,zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
          halt render_json({res: true, redirect_to: "/#/#{@current_uid}/publish/"})
        end
      end
    end

    create_album_and_tracks(zipfiles,category_id,title,tags,user_source,intro,rich_intro,is_records_desc,music_category,is_finished,sharing_to,share_content,p_transcode_res,default_cover_path,default_cover_exlore_height)
    halt render_json({res: true, redirect_to: "/#/#{@current_uid}/album"})
  end

  #编辑专辑 表单页
  def edit_album_page

    halt_404 if request.xhr?

    set_no_cache_header

    redirect_to_login unless @current_uid

    @album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:id], is_deleted: false).first
    halt_error("专辑已删除或者不存在") if @album.nil?

    @album_rich = TrackSetRich.stn(@album.id).where(track_set_id: @album.id).first
    if @album.is_crawler || @album.tracks_order.nil? || @album.tracks_order.empty? 
      direction = @album.is_records_desc ? 'desc' : 'asc'
      @tracks = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: @album.id, is_public: true, is_deleted: false, status: [0, 1]).order("order_num #{direction}, created_at #{direction}")
    else
      @tracks = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: @album.id, is_public: true, is_deleted: false, status: [0, 1]).order("field(id,#{@album.tracks_order})")
    end

    @category = CATEGORIES[@album.category_id]
    
    @checkCaptcha = true
    if !@current_user.isVerified and !@current_user.isVMobile
      @checkCaptcha = $wordfilter_client.checkCaptcha(2, @current_uid, get_client_ip);
    end

    if @current_user.isRobot or @current_user.isVerified
      @capacity_free = 999 #加V用户容量无限制
    else
      default_capacity = Settings.capacity_free
      used_capacity = $stat_user_track_client.getUserTotalTime(@current_uid)
      @capacity_free = default_capacity - used_capacity
    end

    @this_title = "编辑专辑 喜马拉雅-听我想听"

    erb :edit_album_page
  end

  #编辑专辑 action
  def do_update_album

    halt_400 unless @current_uid

    album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:id], is_deleted: false).first
    halt_error("专辑已删除或者不存在") unless album

    if params[:codeid] and !@current_user.isVerified
      if Net::HTTP.get(URI(File.join(Settings.check_root, "/validateAction?codeId=#{params[:codeid]}&userCode=#{CGI.escape(params[:validcode] || '')}"))) == 'false'
        halt render_json({res: false, errors: [['page', '验证码不匹配']]})
      else
        $wordfilter_client.clearCaptcha(2, @current_uid, get_client_ip)
      end
    end

    files = Array.wrap(params[:files]).take(200)
    fileids = Array.wrap(params[:fileids]).take(200)
    halt render_json({res: false, errors: [['page', '数据不正确']]}) if files.length != fileids.length
    zipfiles = fileids.zip(files)

    new_fileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }
    new_fileids_size = new_fileids.size
    halt_403({res: false, errors: [['page', '对不起，您已被暂时禁止发布声音']]}) if new_fileids_size>0 and ( @current_user.isLoginBan or is_user_banned?(@current_uid) )

    #参数整理
    title, intro = params[:title].to_s.chomp, params[:intro].to_s.chomp
    rich_intro = params[:rich_intro].to_s
    category_id = params[:category_id].to_i
    tags = params[:tags].to_s.chomp.squeeze(" ")
    is_records_desc = params[:is_records_desc]=='on'
    is_finished, image = params[:is_finished].to_i, params[:image].to_s
    music_category = params[:sub_category_id]
    sharing_to = params[:sharing_to]
    share_content = params[:share_content]

    catch_errors = catch_upload_basic_errors(title, 1, category_id, intro, '')
    halt render_json({res: false, errors: errors}) if catch_errors.size > 0

    album_track_count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: album.id, is_deleted: false).count
    delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count
    temp_track_count = TempAlbumForm.where(uid: @current_uid, state: 0, album_id: album.id).sum('add_tracks') # 专辑缓存表中的数据也算上
    allcount = delayed_track_count + new_fileids_size + album_track_count + temp_track_count
    halt render_json({res: false, errors: [['page', '哎呀，专辑已经塞满啦']]}) if new_fileids_size > 50 or (allcount >= 200 and new_fileids_size > 0)

    # 专辑信息敏感词验证
    album_dirts = filter_hash( 2, @current_user, get_client_ip, {title:title,intro:intro,tags:tags} )
    halt render_json({res: false, errors: [['files_dirty_words', album_dirts]]}) if album_dirts.size > 0

    # 声音标题敏感词验证
    words = {}
    fileids.each_with_index {|fileid, i| words[fileid.to_s] = files[i] }
    if words.size > 0
      files_dirts = filter_hash(2, @current_user, get_client_ip, words, new_fileids_size > 0)
      halt render_json({res: false, errors: [['files_dirty_words', files_dirts]]}) if files_dirts.size > 0
    end

    if image.present?
      begin
      img_data = Yajl::Parser.parse(image)
      if img_data and img_data['status']
        pic = img_data['data'][0]['processResult']
        default_cover_path = pic['origin']
        default_cover_exlore_height = pic['180n_height']
        is_image_change = true
      end
      rescue
        writelog('check image form data failed')
      end
    end

    if new_fileids_size>0
      transcode_res = TRANSCODE_SERVICE.checkTranscodeState(@current_uid, new_fileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
      p_transcode_res = Yajl::Parser.parse(transcode_res)

      if !p_transcode_res['success']
        writelog('check transcode state failed')
        halt_error('声音转码失败')
      end

      if default_cover_path.nil? and album.cover_path  # 把专辑封面用作声音默认封面
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

    update_album_and_tracks(album,title,intro,rich_intro,category_id,music_category,is_records_desc,is_finished,zipfiles,sharing_to,share_content,p_transcode_res,is_image_change,default_cover_path,default_cover_exlore_height,datetime)
    
    rdt_url ||= "/#/#{@current_uid}/album/"

    halt render_json({res: true, redirect_to: rdt_url})
  end

  # 删除专辑
  def do_destroy_album

    halt_400 unless @current_uid

    album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:id], is_deleted: false).first
    halt render_json({}) unless album

    album.update_attribute(:is_deleted,true)

    # params[:removeSound] 是否删除专辑下的声音
    removeSound = (params[:removeSound].to_s != "false") ? 1 : 2
    is_off = album.is_public && album.status == 1

    topic = album.to_topic_hash.merge(is_feed: true, op_type: removeSound, is_off: is_off)
    $rabbitmq_channel.fanout(Settings.topic.album.destroyed, durable: true).publish(Oj.dump(topic, mode: :compat), content_type: 'text/plain', persistent: true)
    bunny_logger = ::Logger.new(File.join(Settings.log_path, "bunny.#{Time.new.strftime('%F')}.log"))
    bunny_logger.info "album.destroyed.topic #{album.id} #{album.title} #{album.nickname} #{album.updated_at.strftime('%R')}"

    halt render_json({})
  end


  #推荐标签（创建专辑，用户选择种类时读取）
  def get_recommend_tags

    set_no_cache_header

    @tags = HumanRecommendCategoryTag.where(category_id:params[:category_id])
    erb(:_tags_panel,layout:false)
  end

  #未添加到专辑的声音列表
  def get_outside_sound_list
    
    halt render_json([]) unless @current_uid

    records_list = TrackRecord.stn(@current_uid).where(uid: @current_uid, op_type: TrackRecordOrigin::OP_TYPE[:UPLOAD], album_id: nil, is_public: true, is_deleted: false).order('id desc').limit(100)
    response = []
    records_list.each do |r|
      data = {}
      data[:id] = r.id
      data[:title] = r.title
      data[:sound_id] = r.track_id
      response << data
    end
    render_json(response)
  end

end