module DelayedUploadHelper
  include Inet

  def delayed_upload_task(params)

    member = DelayedTrack.where(:uid => @current_uid, :is_deleted => 0).group(:task_count_tag).to_a

    if member.size >= 10
        render json: {res: false, errors: [['publish', '定时发布任务不能超过10条']]}
        return
    end

    date = params[:date]
    hour = params[:hour]
    minutes = params[:minutes]
    a = date.split("-")[0]
    b = date.split("-")[1]
    c = date.split("-")[2]
    datetime = Time.new(a,b,c,hour,minutes).strftime('%Y-%-m-%-d %H:%M:%S')

    if params[:is_album] == 'true'
      if params[:choose_album] and !params[:choose_album].empty? # 选择专辑
        fileids = params[:fileids] || []
        album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:choose_album].to_i, is_deleted: false).first
        count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: album.id, is_public: true, is_deleted: false).count
        delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count || 0
        allcount = fileids.size + count + delayed_track_count
        if count > 200 || allcount > 200
          render json: {res: false, errors: [['add_to_album', '亲，专辑声音数已满,上传声音超过200条了']]}
          return
        end
      end

      title, user_source, intro, category_id = params[:title], params[:user_source], params[:intro], params[:categories].to_i
      tags = params[:tags].squish if params[:tags]
      files = params[:files] || []
      fileids = params[:fileids] || []
      newfileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }

      if !@current_user.isVerified and !@current_user.isVMobile and newfileids.size > 1
        if Net::HTTP.get(URI(File.join(Settings.check_root, "/validateAction?codeId=#{params[:codeid]}&userCode=#{CGI.escape(params[:validcode] || '')}"))) == 'false'
          render json: {res: false, errors: [['page', '验证码不匹配']]}
          return
        end
      end

      # 文件名脏字
      words = {}
      fileids.each_with_index do |fileid, i|
        words[fileid.to_s] = files[i] unless fileid.empty?
      end
      if words.size > 0
        files_dirts = filter_hash(2, @current_user, get_client_ip, words, newfileids.size > 0)
        if files_dirts.size > 0
          render json: {res: false, errors: [['files_dirty_words', files_dirts]]}
          return
        end
      end

      if params[:choose_album] and !params[:choose_album].empty? # 选择专辑
        album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:choose_album].to_i, is_deleted: false).first
        unless album
          render json: {res: false, errors: [['page', '抱歉,无法添加到该专辑']]}
          return
        end

        # 检查新上传的声音转码状态
        if newfileids and newfileids.length > 0
          transcode_res = TRANSCODE_SERVICE.checkTranscodeState(album.uid, newfileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
          p_transcode_res = Yajl::Parser.parse(transcode_res)
          if !p_transcode_res['success']
            writelog('check transcode state failed')
            flash[:error_page_info] = '声音转码失败'
            halt render_json({res: true, redirect_to: "/#/error_page"})
          end
        end

        if album.cover_path
          # 把专辑封面用作声音默认封面
          pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
          default_cover_path = pic['origin']
          default_cover_exlore_height = pic['180n_height']
          # UPLOAD_SERVICE.updateTrackUsed(nil, nil, [Hessian2::TypeWrapper.new(:long, pic['uploadId'])], nil, nil)
        end

        count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: album.id, is_public: true, is_deleted: false).count

        delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count || 0
        allcount = fileids.size + count + delayed_track_count

        if count <= 200 && allcount <= 200
          dalbum = DelayedAlbum.new
          dalbum.uid = @current_uid
          dalbum.nickname = @current_user.nickname
          dalbum.avatar_path = @current_user.logoPic
          dalbum.is_v = @current_user.isVerified
          dalbum.dig_status = @current_user.isVerified ? 1 : 0
          dalbum.human_category_id = @current_user.vCategoryId
          dalbum.title = album.title
          dalbum.intro = intro
          dalbum.short_intro = intro && intro[0, 100]
          dalbum.tags = tags.gsub('_', '-') if tags
          dalbum.user_source = user_source.to_i
          dalbum.category_id = category_id
          dalbum.is_finished = category_id==Category::ID[:book] ? params[:is_finished] : nil
          dalbum.music_category  = params[:categories_music]
          # xiaoqing上传封面插件，返回的数据,没有则不设置封面
          if params[:image] and !params[:image].empty?
            image = Yajl::Parser.parse(params[:image])
            if image and image['status']
              pic = image['data'][0]['processResult']
              dalbum.cover_path = pic['origin']
            end
          end
          dalbum.is_public = params[:is_public].to_s != '0'
          dalbum.is_records_desc = params[:is_records_desc]=='on'
          dalbum.is_publish = true
          dalbum.publish_at = datetime
          dalbum.status = get_default_status(@current_user)
          dalbum.rich_intro = cut_intro(params[:rich_intro])
          dalbum.save
          
          _is_records_desc = params[:is_records_desc]=='on'
          if _is_records_desc and album.is_records_desc != _is_records_desc
            album.update_attributes(is_records_desc:_is_records_desc) 
          end

          task_count_tag = Time.now.to_i
          if newfileids.size <= 100
            # 存专辑下的声音
            track_ids = []
            new_fileid_idx = -1
            newfileids.each_with_index do |fid,index|
              REDIS.incr("#{Settings.delayedpublishtrackcount}.#{Time.new.strftime('%F')}")

              track_origin = Track.new
              track_origin.uid = @current_uid
              track_origin.status = 2
              track_origin.title = params[:files][index]
              track_origin.save

              new_fileid_idx += 1
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
              track.title = files[index]
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

              track_ids << track.id
            end
            rich_intro = clean_html(params[:rich_intro]) if params[:rich_intro]
            # 定时发布queue
            $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode({
              delayed_track_ids: track_ids,
              delete_delayed_album_id: dalbum.id,
              delayed_publish_at: datetime,
              share: [params[:sharing_to], params[:share_content]],
              user_agent: request.headers['user_agent'],
              is_records_desc: params[:is_records_desc],
              rich_intro: rich_intro
            }), content_type: 'text/plain', persistent: true)
          end
        else
          render json: {res: false, errors: [['add_to_album', '亲，专辑声音数已满,上传声音超过200条了']]}
          return
        end
      # 创建专辑 #########################################################
      else
        errors = handle_errors(title, user_source, category_id, intro, tags)
        if errors.size > 0
          render json: {res: false, errors: errors}
          return
        end

        # 专辑信息脏字
        album_dirts = filter_hash(3, @current_user, get_client_ip, {
          title: params[:title],
          intro: params[:intro],
          tags: tags
        }, true)
        if album_dirts.size > 0
          render json: {res: false, errors: [['dirty_words', album_dirts]]}
          return
        end

        album = DelayedAlbum.new
        album.uid = @current_uid
        album.nickname = @current_user.nickname
        album.avatar_path = @current_user.logoPic
        album.is_v = @current_user.isVerified
        album.dig_status = @current_user.isVerified ? 1 : 0
        album.human_category_id = @current_user.vCategoryId
        album.title = title.strip
        album.intro = intro
        album.short_intro = (intro ? intro[0, 100] : nil)
        album.tags = tags.gsub('_', '-') if tags
        album.user_source = user_source.to_i
        album.category_id = category_id
        album.music_category  = params[:categories_music]
        album.is_finished = category_id==Category::ID[:book] ? params[:is_finished] : nil
        # xiaoqing上传封面插件，返回的数据,没有则不设置封面
        if params[:image] and !params[:image].empty?
          image = Yajl::Parser.parse(params[:image])
          if image and image['status']
            pic = image['data'][0]['processResult']
            album.cover_path = pic['origin']
          end
        end
        album.is_public = params[:is_public].to_s != '0'
        album.is_records_desc = params[:is_records_desc]=='on'
        album.is_publish = true
        album.publish_at = datetime
        album.status = get_default_status(@current_user)
        rich_intro = clean_html(params[:rich_intro]) if params[:rich_intro]
        album.rich_intro = cut_intro(rich_intro)
        album.save

        REDIS.incr("#{Settings.delayedpublishalbumcount}.#{Time.new.strftime('%F')}")

          # 检查新上传的声音转码状态
        if newfileids and newfileids.length > 0
          transcode_res = TRANSCODE_SERVICE.checkTranscodeState(album.uid, newfileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
          p_transcode_res = Yajl::Parser.parse(transcode_res)
          if !p_transcode_res['success']
            writelog('check transcode state failed')
            flash[:error_page_info] = '声音转码失败'
            halt render_json({res: true, redirect_to: "/#/error_page"})
          end
        end

        if album.cover_path
          # 把专辑封面用作声音默认封面
          pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
          default_cover_path = pic['origin']
          default_cover_exlore_height = pic['180n_height']
        end

        # 存专辑下的声音
        if newfileids.size <= 100
          new_fileid_idx = -1
          
          track_ids = []
          task_count_tag = Time.now.to_i
          newfileids.each_with_index do |fid,index|

            REDIS.incr("#{Settings.delayedpublishtrackcount}.#{Time.new.strftime('%F')}")

            new_fileid_idx += 1
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
            track.album_id = album.id # 源专辑id
            track.album_title = album.title # 源专辑标题
            track.album_cover_path = album.cover_path
            track.title = files[index]
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

            track.delayed_album_id = album.id
            track.publish_at = datetime
            track.fileid = fid

            track.inet_aton_ip = inet_aton(get_client_ip)
            track.status = album.status
            track.save

            track_ids << track.id
          end
        end
        rich_intro = clean_html(params[:rich_intro]) if params[:rich_intro]
        # 定时发布queue
        $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode({
          delayed_track_ids: track_ids,
          delayed_album_id: album.id.to_s,
          delayed_publish_at: datetime,
          share: [params[:sharing_to], params[:share_content]],
          user_agent: request.headers['user_agent'],
          is_records_desc: params[:is_records_desc],
          rich_intro: rich_intro
        }), content_type: 'text/plain', persistent: true)
      end # else if params[:choose_album] and !params[:choose_album].empty?

      render json: {res: true, redirect_to: "/#/#{@current_uid}/publish/"}
      return
    else
      # 创建单个声音
      if params[:album_id] and params[:album_id].to_i > 0
        album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:album_id], is_deleted: false).first
        count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: params[:album_id], is_public: true, is_deleted: false).count

        delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count || 0
        allcount = 1 + count + delayed_track_count

        if count > 200 || allcount > 200
          render json: {res: false, errors: [['add_to_album', '亲，专辑声音数已满,上传声音超过200条了']]}
          return
        end
      end

      tags = params[:tags].strip.gsub("  "," ") if params[:tags]
      errors = handle_errors(params[:title], params[:user_source], params[:categories], params[:intro], tags)
      if errors.size > 0
        render json: {res: false, errors: errors}
        return
      end

      # 声音信息脏字
      track_dirts = filter_hash(2, @current_user, get_client_ip, {
        title: params[:title],
        intro: params[:intro],
        tags: tags,
        singer: params[:singer],
        singer_category: params[:singer_category],
        author: params[:author],
        composer: params[:composer],
        arrangement: params[:arrangement],
        post_production: params[:post_production],
        lyric: params[:lyric],
        resinger: params[:resinger],
        announcer: params[:announcer],
        composer: params[:composer]
      })

      if track_dirts.size > 0
        render json: {res: false, errors: [['dirty_words', track_dirts]]}
        return
      end

      is_public = params[:is_public].to_s != '0'

      fileids = params[:fileids].map{|fid| Hessian2::TypeWrapper.new(:long, fid)}
      transcode_res = TRANSCODE_SERVICE.checkTranscodeState(@current_uid, fileids)
      p_transcode_res = Yajl::Parser.parse(transcode_res)

      REDIS.incr("#{Settings.delayedpublishtrackcount}.#{Time.new.strftime('%F')}")

      d = p_transcode_res['data'].first
      track_origin = Track.new
      track_origin.uid = @current_uid
      track_origin.status = 2
      track_origin.title = params[:title] || ""
      track_origin.save

      task_count_tag = Time.now.to_i
      track = DelayedTrack.new
      track.task_count_tag = task_count_tag
      track.upload_source = 2 # 网站
      track.is_crawler = false
      track.uid = @current_uid # 源发布者
      track.nickname = @current_user.nickname
      track.avatar_path = @current_user.logoPic
      track.is_v = @current_user.isVerified
      track.dig_status = @current_user.isVerified ? 1 : 0
      track.human_category_id = @current_user.vCategoryId
      track.approved_at = Time.new
      track.title = params[:title]
      track.track_id = track_origin.id
      track.user_source = params[:user_source]
      track.category_id = params[:categories]
      track.music_category = params[:categories_music]
      if tags
        track.tags = tags.gsub('_', '-')
      end
      track.intro = params[:intro]
      track.short_intro = (params[:intro] ? params[:intro][0, 100] : nil)
      track.rich_intro = cut_intro(params[:rich_intro])
      track.singer = params[:singer]
      track.singer_category = params[:singer_category]
      track.author = params[:author]
      track.arrangement = params[:arrangement]
      track.post_production = params[:post_production]
      track.resinger = params[:resinger]
      track.announcer = params[:announcer]
      track.composer = params[:composer]
      track.is_publish = true
      track.is_public = is_public
      track.publish_at = datetime
      lyric = CGI.escapeHTML(Sanitize.clean(params[:lyric], { elements: %w(br) }))[0, 5000] if params[:lyric]
      track.lyric = lyric
      track.fileid = params[:fileids][0]
      track.allow_download =  params[:allow_download]
      track.allow_comment = params[:allow_comment]
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

      dalbum = DelayedAlbum.new
      if params[:album_id] and params[:album_id].to_i > 0
        album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:album_id], is_deleted: false).first
        count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: params[:album_id], is_public: true, is_deleted: false).count

        delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count || 0
        allcount = 1 + count + delayed_track_count

        if count <= 200 && allcount <= 200
          if album.cover_path
            # 把专辑封面用作声音默认封面
            pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
            default_cover_path = pic['origin']
            default_cover_exlore_height = pic['180n_height']
          end
          track.cover_path = default_cover_path
          track.explore_height = default_cover_exlore_height
          track.album_cover_path = album.cover_path
 
          dalbum.uid = @current_uid
          dalbum.nickname = @current_user.nickname
          dalbum.avatar_path = @current_user.logoPic
          dalbum.is_v = @current_user.isVerified
          dalbum.dig_status = @current_user.isVerified ? 1 : 0
          dalbum.human_category_id = @current_user.vCategoryId
          dalbum.title = album.title
          dalbum.intro = intro
          dalbum.short_intro = (intro ? intro[0, 100] : nil)
          if tags
            dalbum.tags = tags.gsub('_', '-')
          end
          dalbum.user_source = params[:user_source].to_i
          dalbum.category_id = params[:categories].to_i
          dalbum.music_category  = params[:categories_music]
          dalbum.is_finished = category_id==Category::ID[:book] ? params[:is_finished] : nil
          dalbum.cover_path = album.cover_path
          dalbum.is_public = params[:is_public].to_s != '0'
          dalbum.is_records_desc = params[:is_records_desc]=='on'
          dalbum.is_publish = true
          dalbum.publish_at = datetime
          dalbum.status = get_default_status(@current_user)
          dalbum.rich_intro = cut_intro(params[:rich_intro])
          dalbum.save

          track.delayed_album_id = dalbum.id # 临时专辑id
          track.album_id = album.id
          track.album_title = album.title

        else
          render json: {res: false, errors: [['add_to_album', '亲，专辑声音数已满,上传声音超过200条了']]}
          return
        end
      end

      images = params[:image]
      image_ids = []
      picture_images = []
      if images and images.length > 0
        images.each_with_index do |image,index|
          covers = Yajl::Parser.parse(image)
          if covers['status'] and covers['status'] != false
            if covers['data'] and covers['data'].first['uploadTrack']
              cover = covers['data'].first
              cover_track = cover['uploadTrack']
              image_ids << cover_track['id'].to_i
              if index == 0 #设置第一张为声音封面
                if cover['processResult']
                  paths = cover['processResult']
                  track.cover_path = paths["origin"]
                  track.explore_height = paths["180n_height"]
                else
                  track.cover_path = cover_track['url']
                end
              end

              if cover['processResult']
                paths = cover['processResult']
                picture_images << {picture_path:paths["origin"],explore_height:paths["180n_height"]}
              else
                picture_images << {picture_path:cover_track['url'],explore_height:nil}
              end
            end
          end
        end
      end

      picture_images.each_with_index do |image,index|
        TrackPicture.create(track_id:track_origin.id,uid:@current_uid,picture_path:image[:picture_path],explore_height:image[:explore_height],order_num:index+1)
      end if picture_images.length > 0

      track.inet_aton_ip = inet_aton(get_client_ip)
      track.status = get_default_status(@current_user)
      track.save

      track_ids = []
      track_ids << track.id
      rich_intro = clean_html(params[:rich_intro]) if params[:rich_intro]
      $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode({
        track_id: track_origin.id,
        delayed_track_ids: track_ids,
        delete_delayed_album_id: dalbum.id,
        delayed_publish_at: datetime,
        share: [params[:sharing_to], params[:share_content]],
        user_agent: request.headers['user_agent'],
        rich_intro: rich_intro
      }), content_type: 'text/plain', persistent: true)

      render json: {res: true, redirect_to: "/#/#{@current_uid}/publish/"}
    end
  end

  def create_old_album(params)

    fileids = params[:fileids] || []
    newfileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }

    newfile = []
    fileids.each_with_index do |fileid,index|
      if !%w(r m).include?(fileid[0])
        newfile << params[:files][index]
      end
    end

    if newfileids.blank?
      render json: {res: true, redirect_to: "/#/#{@current_uid}/album/"}
      return
    end
    date = params[:date]
    hour = params[:hour]
    minutes = params[:minutes]
    a = date.split("-")[0]
    b = date.split("-")[1]
    c = date.split("-")[2]
    datetime = Time.new(a,b,c,hour,minutes).strftime('%Y-%-m-%-d %H:%M:%S')

    album = Album.stn(@current_uid).where(uid: @current_uid, id: params[:id].to_i, is_deleted: false).first
    unless album
      render json: {res: false, errors: [['page', '抱歉,无法添加到该专辑']]}
      return
    end

    # fileids = params[:fileids] || []
    # newfileids = fileids.select{|fid| !%w(r m).include?(fid[0]) }
    # 检查新上传的声音转码状态
    if newfileids and newfileids.length > 0
      transcode_res = TRANSCODE_SERVICE.checkTranscodeState(album.uid, newfileids.collect{ |id| Hessian2::TypeWrapper.new(:long, id) })
      p_transcode_res = Yajl::Parser.parse(transcode_res)
      if !p_transcode_res['success']
        writelog('check transcode state failed')
        flash[:error_page_info] = '声音转码失败'
        halt render_json({res: true, redirect_to: "/#/error_page"})
      end
    end

    if album.cover_path
      # 把专辑封面用作声音默认封面
      pic = UPLOAD_SERVICE2.uploadCoverFromExistPic(album.cover_path, 3)
      default_cover_path = pic['origin']
      default_cover_exlore_height = pic['180n_height']
      # UPLOAD_SERVICE.updateTrackUsed(nil, nil, [Hessian2::TypeWrapper.new(:long, pic['uploadId'])], nil, nil)
    end

    count = TrackRecord.stn(@current_uid).where(uid: @current_uid, album_id: album.id, is_public: true, is_deleted: false).count

    delayed_track_count = DelayedTrack.where(uid: @current_uid, is_deleted: false, album_id: album.id).count || 0
    allcount = newfileids.size + count + delayed_track_count
    intro = params[:intro]
    tags = params[:tags]
    user_source = params[:user_source]
    category_id = params[:category_id].to_i
    files = params[:files]
    if count <= 200 && allcount <= 200
      dalbum = DelayedAlbum.new
      dalbum.uid = @current_uid
      dalbum.nickname = @current_user.nickname
      dalbum.avatar_path = @current_user.logoPic
      dalbum.is_v = @current_user.isVerified
      dalbum.dig_status = @current_user.isVerified ? 1 : 0
      dalbum.human_category_id = @current_user.vCategoryId
      dalbum.title = album.title
      dalbum.intro = intro
      dalbum.short_intro = intro && intro[0, 100]
      dalbum.tags = tags.gsub('_', '-') if tags
      dalbum.user_source = user_source.to_i
      dalbum.category_id = category_id
      dalbum.music_category  = params[:sub_category_id]
      dalbum.is_finished = category_id==Category::ID[:book] ? params[:is_finished] : nil      

      if params[:image] and !params[:image].empty?
        image = Yajl::Parser.parse(params[:image])
        if image and image['status']
          pic = image['data'][0]['processResult']
          dalbum.cover_path = pic['origin']
        end
      end
      dalbum.is_public = params[:is_public].to_s != '0'
      dalbum.is_records_desc = params[:is_records_desc]=='on'
      dalbum.is_publish = true
      dalbum.publish_at = datetime
      dalbum.status = get_default_status(@current_user)
      dalbum.rich_intro = cut_intro(params[:rich_intro])
      dalbum.save
      
      _is_records_desc = params[:is_records_desc]=='on'
      if _is_records_desc and album.is_records_desc != _is_records_desc
        album.update_attributes(is_records_desc:_is_records_desc) 
      end

      task_count_tag = Time.now.to_i
      if newfileids.size <= 100
        # 存专辑下的声音
        track_ids = []
        new_fileid_idx = -1
        newfileids.each_with_index do |fid,index|
          

          track_origin = Track.new
          track_origin.uid = @current_uid
          track_origin.status = 2
          track_origin.title = newfile[index]
          track_origin.save

          new_fileid_idx += 1
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

          track_ids << track.id
        end
        rich_intro = clean_html(params[:rich_intro]) if params[:rich_intro]
        # 定时发布queue
        $rabbitmq_channel.queue('timing.publish.queue', durable: true).publish(Yajl::Encoder.encode({
          delayed_track_ids: track_ids,
          delete_delayed_album_id: dalbum.id,
          delayed_publish_at: datetime,
          share: [params[:sharing_to], params[:share_content]],
          user_agent: request.headers['user_agent'],
          is_records_desc: params[:is_records_desc],
          rich_intro: rich_intro
        }), content_type: 'text/plain', persistent: true)
      end
    else
      render json: {res: false, errors: [['add_to_album', '亲，专辑声音数已满,上传声音超过200条了']]}
      return
    end
    render json: {res: true, redirect_to: "/#/#{@current_uid}/publish/"}
  end
end