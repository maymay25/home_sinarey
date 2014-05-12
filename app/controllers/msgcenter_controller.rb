class MsgcenterController < ApplicationController
  include ApnDispatchHelper

  set :views, ['msgcenter','application']

  def dispatch(action)
    super(:center,action)
    redirect_to_root
    method(action).call
  end

  ### 系统通知列表
  def notice_page

    halt_404 unless request.xhr?

    set_no_cache_header
    redirect_to_login('/#/msgcenter/notice') unless @current_uid

    xima = $profile_client.queryUserBasicInfo(1)

    # 上次收到的最后一条公告 喜马发的
    sysmsg_count = Inbox.stn(@current_uid).where(to_uid: @current_uid, message_type: 5, uid: xima.uid).count

    if sysmsg_count > 0
      # 收过公告 喜马发的
      last = Inbox.stn(@current_uid).where(to_uid: @current_uid, message_type: 5, uid: xima.uid).last
      if last and last.anno_id
        # 收新的公告 喜马发的
        Announcement.where('id > ? and created_at > ? and uid = ?', last.anno_id, Time.at(@current_user.createdTime/1000), xima.uid).each do |a|
          Inbox.create(uid: xima.uid,
                nickname: xima.nickname,
                avatar_path: xima.logoPic,
                to_uid: @current_uid,
                to_nickname: @current_user.nickname,
                to_avatar_path: @current_user.logoPic,
                message_type: 5,
                content: a.content,
                anno_id: a.id,
                anno_created_at: a.created_at)
        end
      end
    else
      # 从未收过公告，收注册之后出的公告 喜马发的
      Announcement.where('created_at > ? and uid = ?', Time.at(@current_user.createdTime/1000), xima.uid).each do |a|
        Inbox.create(uid: xima.uid,
              nickname: xima.nickname,
              avatar_path: xima.logoPic,
              to_uid: @current_uid,
              to_nickname: @current_user.nickname,
              to_avatar_path: @current_user.logoPic,
              message_type: 5,
              content: a.content,
              anno_id: a.id,
              anno_created_at: a.created_at)
      end
    end

    # 拿公告和系统私信
    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    all_messages = Inbox.stn(@current_uid).where(to_uid: @current_uid, message_type: [5, 6], has_read: false)
    @messages_count = all_messages.count
    @messages = all_messages.order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    $counter_client.set(Settings.counter.user.new_notice, @current_uid, 0) if @page==1

    set_my_counts

    erb_js(:notice_page_js)
  end

  ##ajax 删除系统通知
  def destroy_notice

    set_no_cache_header
    
    halt render_json({result: "unlogin"}) unless @current_uid

    message = Inbox.stn(@current_uid).where(id: params[:id]).first
    message.update_attribute("has_read", true) if message

    render_json({result: "success"})
  end

  ### @我的列表
  def referme_page

    halt_404 unless request.xhr?

    set_no_cache_header
    
    redirect_to_login('/#/msgcenter/referme') unless @current_uid

    all_refermes = Inbox.stn(@current_uid).where(to_uid: @current_uid).order('id desc')

    @refermes_comment_count = all_refermes.where(message_type: 4).count
    @refermes_relay_count = all_refermes.where(message_type: 8).count
    @refermes_all_count = @refermes_comment_count + @refermes_relay_count

    if params[:type] == "relay"
      all_refermes = all_refermes.where(message_type: 8)
      @refermes_count = @refermes_relay_count
    elsif params[:type] == "comment"
      all_refermes = all_refermes.where(message_type: 4)
      @refermes_count = @refermes_comment_count
    else
      all_refermes = all_refermes.where(message_type: [4,8])
      @refermes_count = @refermes_all_count
    end

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    @refermes = all_refermes.offset((@page-1)*@per_page).limit(@per_page)

    $counter_client.set(Settings.counter.user.new_quan, @current_uid, 0) if @page==1

    erb_js(:referme_page_js)
  end

  ### 评论列表
  def comment_page

    halt_404 unless request.xhr?

    set_no_cache_header
    
    redirect_to_login('/#/msgcenter/comment') unless @current_uid

    inbox_comments = Inbox.stn(@current_uid).where(to_uid: @current_uid, message_type: [2, 3])
    @inbox_count = inbox_comments.count

    outbox_comments = Outbox.stn(@current_uid).where(uid: @current_uid, message_type: [2, 3])
    @outbox_count = outbox_comments.count

    @all_count = @inbox_count + @outbox_count

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    if params[:type]=="out"
      @comments_count = @outbox_count
      @comments = outbox_comments.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
    else
      @comments_count = @inbox_count
      @comments = inbox_comments.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
    end

    $counter_client.set(Settings.counter.user.new_comment, @current_uid, 0) if @page==1

    erb_js(:comment_page_js)
  end

  # 创建评论 # params: track_id parent_id second content no_more_alert sharing_to
  def create_comment
    
    set_no_cache_header

    halt_400 unless @current_uid

    halt_403({res: false, message: "", msg: '对不起，您已被暂时禁止发布评论'}) if @current_user.isLoginBan or is_user_banned?(@current_uid)
    
    if params[:content].blank?
      halt render_json({res: false, message: "", msg: '评论不能为空喔。'})
    else
      res = $wordfilter_client.wordFilters(5, @current_uid, get_client_ip, params[:content])
      if res == -11
        halt render_json({res: false, message: "", msg: "评论内容非法"})
      elsif res == -19
        halt render_json({res: false, message: "", msg: "评论内容包含不支持的字符，请修改！"})
      end
    end

    tir = TrackInRecord.fetch(params[:track_id])

    halt render_json({res: false, message: "", msg: '该声音不存在'}) if tir.nil? or tir.is_deleted

    halt render_json({res: false, message: "", msg: '抱歉，该声音正在审核中'}) if tir.status == 0

    halt render_json({res: false, message: "", msg: '该声音已经下架'}) if tir.status != 1

    halt render_json({res: false, message: "", msg: '私密声音不能评论'}) unless tir.is_public

    if params[:parent_id] and !params[:parent_id].empty?
      # 回复评论
      pcomment = Comment.stn(params[:track_id]).where(id: params[:parent_id]).first
      halt render_json({res: false, message: "", msg: '该评论不存在'}) unless pcomment
      master_comment_id = pcomment.parent_id || pcomment.id
    end

    #黑名单
    halt render_json({res: false, message: "", msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid: tir.uid, black_uid: @current_uid).first

    track_ps = PersonalSetting.where(uid: tir.uid).first
    if track_ps
      u = $profile_client.queryUserBasicInfo(tir.uid)
      res = {res: false, message: "", msg: '由于对方的隐私设置，发送失败'}
      case track_ps.allow_comment
      when 2
        if !@current_user.isVerified and !Following.stn(tir.uid).where(uid: tir.uid, following_uid: @current_uid).any? and !Follower.stn(tir.uid).where(uid: @current_uid, following_uid: tir.uid).any?
          halt render_json(res)
        end
      when 3
        unless Following.stn(tir.uid).where(uid: tir.uid, following_uid: @current_uid).any?
          render_json(res)
        end
      when 4
        render_json(res)
      end
    end
    
    if pcomment
      # 回复评论

      # 评论
      comment = Comment.create(uid: @current_uid,
        track_id: tir.track_id,
        track_uid: tir.uid,
        track_upload_source: tir.upload_source,
        track_nickname: tir.nickname,
        track_title: tir.title,
        track_duration: tir.duration,
        track_created_at: tir.created_at,
        track_avatar_path: tir.avatar_path,
        upload_source: 2,
        second: params[:second],
        parent_id: master_comment_id,
        content: params[:content],
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic,
        play_path: tir.play_path,
        play_path_32: tir.play_path_32,
        play_path_64: tir.play_path_64,
        play_path_128: tir.play_path_128,
        user_source: tir.user_source,
        cover_path: tir.cover_path
      )

      # 发件箱 我评论的 评论回复

      Outbox.create(uid: @current_uid,
        nickname: @current_user.nickname,
        to_uid: tir.uid,
        to_nickname: tir.nickname,
        message_type: 3,
        upload_source: 2,
        content: params[:content],
        track_id: tir.track_id, 
        track_title: tir.title, 
        track_cover_path: tir.cover_path, 
        track_uid: tir.uid, 
        track_nickname: tir.nickname, 
        comment_id: comment.id, 
        pcomment_id: master_comment_id, 
        pcomment_content: pcomment.content[0, 59],
        second: params[:second],
        avatar_path: @current_user.logoPic,
        extra_json: { 
          track_id: tir.track_id, track_title: tir.title, track_cover_path: tir.cover_path, 
          track_uid: tir.uid, track_nickname: tir.nickname, comment_id: comment.id, 
          pcomment_id: master_comment_id, pcomment_content: pcomment.content[0, 59], second: params[:second]
        }.to_json,
        to_avatar_path: tir.avatar_path
      )
    else
      # 评论声音
      # 评论
      comment = Comment.create(uid: @current_uid,
        track_id: tir.track_id,
        track_uid: tir.uid,
        track_upload_source: tir.upload_source,
        track_nickname: tir.nickname,
        track_title: tir.title,
        track_duration: tir.duration,
        track_created_at: tir.created_at,
        track_avatar_path: tir.avatar_path,
        upload_source: 2,
        second: params[:second],
        parent_id: nil,
        content: params[:content],
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic,
        play_path: tir.play_path,
        play_path_32: tir.play_path_32,
        play_path_64: tir.play_path_64,
        play_path_128: tir.play_path_128,
        user_source: tir.user_source,
        cover_path: tir.cover_path
      )

      # 发件箱 我评论的 
      Outbox.create(uid: @current_uid,
        nickname: @current_user.nickname,
        to_uid: tir.uid,
        to_nickname: tir.nickname,
        message_type: 2,
        upload_source: 2,
        content: params[:content],
        track_id: tir.track_id, 
        track_title: tir.title, 
        track_cover_path: tir.cover_path, 
        track_uid: tir.uid, 
        track_nickname: tir.nickname, 
        comment_id: comment.id, 
        second: params[:second],
        avatar_path: @current_user.logoPic,
        extra_json: {
          track_id: tir.track_id, track_title: tir.title, track_cover_path: tir.cover_path, 
              track_uid: tir.uid, track_nickname: tir.nickname, comment_id: comment.id, second: params[:second] 
            }.to_json,
        to_avatar_path: tir.avatar_path
      )
    end

    # 声音的评论数
    $counter_client.incr(Settings.counter.track.comments, comment.track_id, 1)

    topic_hash = comment.to_topic_hash
    current_ps = PersonalSetting.where(uid: @current_uid).first

    topic_hash[:is_feed] = current_ps.nil? || current_ps.is_feed_comment==true

    $rabbitmq_channel.fanout(Settings.topic.comment.created, durable: true).publish(Yajl::Encoder.encode(topic_hash), content_type: 'text/plain', persistent: true)

    $rabbitmq_channel.queue('comment.created.dj', durable: true).publish(Yajl::Encoder.encode({
      track_id: comment.track_id,
      id: comment.id,
      mid: master_comment_id,
      pid: params[:parent_id],
      sharing_to: params[:sharing_to],
      dotcom: Settings.home_root,
      is_mob: false
    }), content_type: 'text/plain')

    # 同步分享确认, 不再提示
    unless params[:no_more_alert].nil? || params[:no_more_alert].empty?
      $sync_set_client.noMoreCommentSyncAlert(@current_uid, params[:no_more_alert] == 'true')
    end

    track_comments_count = $counter_client.get(Settings.counter.track.comments, comment.track_id)

    comment_h = {
      content: puts_face(comment.content), 
      created_at: comment.created_at, 
      id: comment.id, 
      nickname: comment.nickname, 
      avatar_url: file_url(comment.avatar_path),
      parent_id: comment.parent_id, 
      second: comment.second, 
      track_id: comment.track_id, 
      uid: comment.uid,
      track_comments_count: track_comments_count
    }
    
    render_json(comment_h)
  end

  # 删除评论
  def destroy_comment

    set_no_cache_header

    halt_400 unless @current_uid
    
    comment = Comment.stn(params[:track_id]).where(id: params[:comment_id]).first
    if comment.uid == @current_uid or comment.track_uid == @current_uid
      comment.destroy

      # 发已删除topic
      $rabbitmq_channel.fanout(Settings.topic.comment.destroyed, durable: true).publish(Yajl::Encoder.encode({
        id: comment.id,
        uid: comment.uid,
        track_id: comment.track_id,
        updated_at: Time.new,
        created_at: comment.created_at
      }), content_type: 'text/plain', persistent: true)

      $counter_client.decr(Settings.counter.track.comments, comment.track_id, 1)
    end

    render_json({res: true, msg: print_message(:success)})
  end

  ### 私信列表
  def letter_page

    halt_404 unless request.xhr?

    set_no_cache_header
    
    redirect_to_login('/#/msgcenter/letter') unless @current_uid

    receive_notice

    conditions = ["linkman_nickname like ? or last_chat_content like ?", "%#{params[:q]}%", "%#{params[:q]}%"] if params[:q] and !params[:q].empty?  #搜索条件
    linkmens = Linkman.stn(@current_uid).where(uid: @current_uid).where(conditions).order('last_chat_at desc')
    @linkmen_count = linkmens.count

    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = 10
    @linkmen = linkmens.offset((@page-1)*@per_page).limit(@per_page)

    @last_chats = {}
    @linkmen.each do |l|
        last = Chat.stn(@current_uid).where(uid: @current_uid, with_uid: l.linkman_uid).order('created_at desc').first
      # 延迟删除没有聊天记录的联系人
      unless last
        l.destroy
        next
      end
      @last_chats[l.id] = last
    end

    uids = @linkmen.collect{|l| l.linkman_uid}
    if uids.size > 0
      @users = $profile_client.getMultiUserBasicInfos(uids)
    else
      @users = {}
    end

    $counter_client.set(Settings.counter.user.new_message, @current_uid, 0) if @page==1

    erb_js(:letter_page_js)
  end

  ### 私信详细页
  def letter_show

    halt_404 unless request.xhr?

    set_no_cache_header

    redirect_to_login('/#/msgcenter/letter') unless @current_uid

    @with_user = $profile_client.queryUserBasicInfo(params[:uid].to_i)
    halt_404 unless @with_user

    receive_notice if params[:uid].to_i == 2

    @chats = Chat.stn(@current_uid).where(uid: @current_uid, with_uid: @with_user.uid).order('created_at desc')
    $counter_client.set(Settings.counter.user.new_message, @current_uid, 0)

    linkman = Linkman.stn(@current_uid).where(uid: @current_uid, linkman_uid: @with_user.uid).first
    linkman.update_attributes(no_read_count: 0) if linkman

    erb_js(:letter_show_js)
  end

  ##ajax 发私信 #params: to_nickname, content
  def create_letter

    set_no_cache_header
    
    halt_400 unless @current_uid

    halt render_json({res: false, msg: print_message(:params_missing, "to_nickname")}) unless params[:to_nickname]

    to_profiles = $profile_client.getProfileByNickname(params[:to_nickname])
    halt render_json({res: false, msg: print_message(:record_not_found, "找不到#{params[:to_nickname]}")}) if to_profiles.empty?

    to_profile = to_profiles.first
    #不能发给自己
    halt render_json({res: false, msg: print_message(:validation_failed, "不能发给自己")}) if @current_uid == to_profile.uid
    
    #内容不能为空
    halt render_json({res: false, msg: print_message(:params_missing, "content")}) unless params[:content] or params[:content].empty?
      
    #黑名单
    halt render_json({res: false, msg: '由于对方的设置，无法进行此操作'}) if BlackUser.where(uid:to_profile.uid,black_uid:@current_uid).first

    to_ps = PersonalSetting.where(uid: to_profile.uid).first
    if to_ps 
      res = {res: false, msg: "由于对方的隐私设置，发送失败"}
      case to_ps.allow_message
      when 2
        if !@current_user.isVerified and !Following.stn(to_profile.uid).where(uid: to_profile.uid, following_uid: @current_uid).any? and !Follower.stn(to_profile.uid).where(uid: @current_uid, following_uid: to_profile.uid).any?
          halt render_json(res)
        end
      when 3
        unless Following.stn(to_profile.uid).where(uid: to_profile.uid, following_uid: @current_uid).any?
          halt render_json(res)
        end
      when 4
        halt render_json(res)
      end
    end

    chat = nil
    ActiveRecord::Base.transaction do 
      # 我的联系人他
      linkman = Linkman.stn(@current_uid).where(uid: @current_uid, linkman_uid: to_profile.uid).first
      now = Time.new
      if linkman
        linkman.last_chat_at = now
        linkman.last_chat_content = params[:content]
        linkman.save
      else
        Linkman.create(uid: @current_uid, 
          nickname: @current_user.nickname,
          avatar_path: @current_user.logoPic,
          linkman_uid: to_profile.uid,
          linkman_nickname: to_profile.nickname,
          linkman_avatar_path: to_profile.logoPic,
          no_read_count: 0,
          last_chat_at: now,
          last_chat_content: params[:content]
        )
      end

      # 他的联系人我
      to_linkman = Linkman.stn(to_profile.uid).where(uid: to_profile.uid, linkman_uid: @current_uid).first
      if to_linkman
        to_linkman.no_read_count = to_linkman.no_read_count + 1
        to_linkman.last_chat_at = now
        to_linkman.last_chat_content = params[:content]
        to_linkman.save
      else
        Linkman.create(
          uid: to_profile.uid, 
          nickname: to_profile.nickname,
          avatar_path: to_profile.logoPic,
          linkman_uid: @current_uid,
          linkman_nickname: @current_user.nickname,
          linkman_avatar_path: @current_user.logoPic,
          no_read_count: 1,
          last_chat_at: now,
          last_chat_content: params[:content]
        )
      end

      # 发
      chat = Chat.create(uid: @current_uid,
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic,
        with_uid: to_profile.uid,
        with_nickname: to_profile.nickname,
        with_avatar_path: to_profile.logoPic,
        is_in: false,
        content: params[:content],
        upload_source: 2
      )

      # 收
      Chat.create(uid: to_profile.uid,
        nickname: to_profile.nickname,
        avatar_path: to_profile.logoPic,
        with_uid: @current_uid,
        with_nickname: @current_user.nickname,
        with_avatar_path: @current_user.logoPic,
        is_in: true,
        content: params[:content],
        upload_source: 2
      )
    end

    $rabbitmq_channel.queue('message.created.dj', durable: true).publish(Yajl::Encoder.encode({
      uid: chat.uid,
      chat_id: chat.id
    }), content_type: 'text/plain')

    chat.content = puts_face(params[:content])
    render_json({res: chat, msg: print_message(:success)})
  end

  ##ajax 删除私信
  def destroy_letter

    set_no_cache_header
    
    halt_400 unless @current_uid

    chat = Chat.stn(@current_uid).where(id: params[:id]).first
    chat.destroy

    render_json({res: true, msg: print_message(:success)})
  end

  ##ajax 批量删私信 params: ids[] example: ['o59', 'i95']
  def batch_destroy_letter

    set_no_cache_header
    
    halt_400 unless @current_uid

    params[:ids].each do |id|
      chat = Chat.stn(@current_uid).where(id: id).first
      chat.destroy
    end

    render_json({res: true, msg: print_message(:success)})
  end

  ##ajax 删关于ta的私信
  def destroy_letter_with_uid

    set_no_cache_header
    
    halt_400 unless @current_uid

    Chat.stn(@current_uid).where(uid: @current_uid, with_uid: params[:uid]).each do |c|
      c.destroy
    end
   
    render_json({res: true, msg: print_message(:success)})
  end

  ### 赞通知列表
  def like_page

    halt_404 unless request.xhr?

    set_no_cache_header
    
    redirect_to_login('/#/msgcenter/like') unless @current_uid

    all_likes = Inbox.stn(@current_uid).where(to_uid: @current_uid, message_type: 7)
    
    @page = (tmp = params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    @likes_count = all_likes.count
    @likes = all_likes.order('id desc').offset((@page-1)*@per_page).limit(@per_page)

    $counter_client.set(Settings.counter.user.new_like, @current_uid, 0) if @page==1

    erb_js(:like_page_js)
  end

  ##ajax 删除赞通知
  def destroy_like

    set_no_cache_header
    
    halt render_json({res: false, message: "login", msg: print_message(:params_missing, "current uid")}) unless @current_uid
    
    halt render_json({res: false, message: "need id", msg: '评论不能为空喔。'}) unless params[:id]

    like = Inbox.stn(@current_uid).where(id: params[:id]).first
    like.destroy

    render_json({result: "success"})
  end


  private
  
  def receive_notice
    # 收公告 拉雅发的
    laya = $profile_client.queryUserBasicInfo(2)

    last_receive = ReceiveLaya.where(uid: @current_uid).first

    if last_receive
      # 收过公告 拉雅发的
      annos = Announcement.where('id > ? and created_at > ? and uid = ?', last_receive.anno_id, Time.at(@current_user.createdTime/1000), laya.uid)
      if annos.size > 0
        ActiveRecord::Base.transaction do 
          # 收新的公告 拉雅发的
          annos.each do |a|
            Chat.create(uid: @current_uid,
              nickname: @current_user.nickname,
              avatar_path: @current_user.logoPic,
              with_uid: laya.uid,
              with_nickname: laya.nickname,
              with_avatar_path: laya.logoPic,
              is_in: true,
              content: a.content,
              anno_id: a.id
            )
          end
          last_receive.anno_id = annos.last.id
          last_receive.save
        end
        check_my_laya(annos.size)
      end
    else
      # 从未收过公告，收注册之后出的公告 拉雅发的
      annos = Announcement.where('created_at > ? and uid = ?', Time.at(@current_user.createdTime/1000), laya.uid)
      if annos.size > 0
        ActiveRecord::Base.transaction do 
          annos.each do |a|
            Chat.create(uid: @current_uid,
              nickname: @current_user.nickname,
              avatar_path: @current_user.logoPic,
              with_uid: laya.uid,
              with_nickname: laya.nickname,
              with_avatar_path: laya.logoPic,
              is_in: true,
              content: a.content,
              anno_id: a.id
            )
          end
          ReceiveLaya.create(uid: @current_uid, anno_id: annos.last.id)
        end
        check_my_laya(annos.size)
      end
    end

  end

  def check_my_laya(new_annos_count = 0)
    laya = $profile_client.queryUserBasicInfo(2)
    linkman = Linkman.stn(@current_uid).where(uid: @current_uid, linkman_uid: 2).first
    now = Time.new
    if linkman 
      linkman.last_chat_at = now
      linkman.no_read_count += new_annos_count
      linkman.save
    else
      Linkman.create(uid: @current_uid, 
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic,
        linkman_uid: laya.uid,
        linkman_nickname: laya.nickname,
        linkman_avatar_path: laya.logoPic,
        no_read_count: new_annos_count,
        last_chat_at: now
      )
    end
  end


end
