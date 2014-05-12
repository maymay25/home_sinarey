class PersonalSettingsController < ApplicationController

  set :views, ['personal_settings','application']

  def dispatch(action)
    super(:personal_settings,action)
    method(action).call
  end

  #个人消息设置
  def message_page

    redirect_to_root

    halt_404 unless request.xhr?

    set_no_cache_header

    redirect_to_login("/#/personal_settings/message") unless @current_uid

    @personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)

    halt erb_js(:message_page_js)
  end

  #更新个人消息设置
  def update_message
    set_no_cache_header
    halt render_json({result: "unlogin"}) unless @current_uid
    begin
      query = {}
      query[:notice_fan] = params[:notice_fan].present?
      query[:notice_message] = params[:notice_message].present?
      query[:notice_comment] = params[:notice_comment].present?
      query[:notice_quan] = params[:notice_quan].present?
      query[:notice_favorite] = params[:notice_favorite].present?

      query[:is_push_new_follower] = params[:notice_fan].present?
      query[:is_push_new_message] = params[:notice_message].present?
      query[:is_push_new_comment] = params[:notice_comment].present?
      query[:is_push_new_quan] = params[:notice_quan].present?
      
      personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)
      personal_setting.update_attributes(query)
      halt render_json({result: "success"})
    rescue
      halt render_json({result: "failure", msg: "修改失败"})
    end
  end

  #个人隐私设置
  def privacy_page

    redirect_to_root

    set_no_cache_header

    halt_404 unless request.xhr?

    redirect_to_login("/#/personal_settings/privacy") unless @current_uid

    @personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)

    halt erb_js(:privacy_page_js)
  end

  #更新个人隐私设置
  def update_privacy
    set_no_cache_header
    halt render_json({result: "unlogin"}) unless @current_uid
    begin
      query = {}
      query[:allow_comment] = params[:allow_comment] if params[:allow_comment]
      query[:allow_message] = params[:allow_message] if params[:allow_message]
      query[:allow_at_me_content] = params[:allow_at_me_content] if params[:allow_at_me_content]
      personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)
      personal_setting.update_attributes(query)
      halt render_json({result: "success"})
    rescue
      halt render_json({result: "failure", msg: "修改失败"})
    end
  end

  #黑名单设置
  def blacklist_page

    redirect_to_root

    set_no_cache_header

    halt_404 unless request.xhr?

    redirect_to_login("/#/personal_settings/blacklist") unless @current_uid

    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = 10

    all_blacklist = BlackUser.where(uid:@current_uid)
    @blacklist_count = all_blacklist.count
    @blacklist = all_blacklist.order('created_at desc').offset((@page-1)*@per_page).limit(@per_page)
    if @blacklist.size > 0
      @profile_users = $profile_client.getMultiUserBasicInfos(@blacklist.collect{|b| b.black_uid })
    end

    halt erb_js(:blacklist_page_js)
  end

  #加入黑名单
  def add_to_blacklist
    set_no_cache_header
    if params[:uid] and @current_uid
      black_user = BlackUser.where(uid:@current_uid,black_uid: params[:uid]).first
      unless black_user
        BlackUser.create(uid:@current_uid,black_uid: params[:uid])
      end

      #取消关注
      following = Following.stn(@current_uid).where(uid: @current_uid, following_uid: params[:uid]).first
      if following 
        following.destroy
        $rabbitmq_channel.queue('following.destroyed.rb', durable: true).publish(Yajl::Encoder.encode({
          id: following.id,
          uid: following.uid,
          following_uid: following.following_uid,
          is_auto_push: following.is_auto_push,
          nickname: following.nickname,
          avatar_path: following.avatar_path,
          following_nickname: following.following_nickname,
          following_avatar_path: following.following_avatar_path
        }), content_type: 'text/plain')
      end
      
      #移除粉丝
      following = Following.stn(params[:uid]).where(uid: params[:uid], following_uid: @current_uid).first
      if following
        following.destroy
        $rabbitmq_channel.queue('following.destroyed.rb', durable: true).publish(Yajl::Encoder.encode({
          id: following.id,
          uid: following.uid,
          following_uid: following.following_uid,
          is_auto_push: following.is_auto_push,
          nickname: following.nickname,
          avatar_path: following.avatar_path,
          following_nickname: following.following_nickname,
          following_avatar_path: following.following_avatar_path
        }), content_type: 'text/plain')
      end

      success, message = true, '添加黑名单成功'
    else
      success, message = false, '添加失败'
    end

    halt render_json({success: success, message: message})
  end

  #移出黑名单
  def remove_from_blacklist
    set_no_cache_header
    if params[:uid] and @current_uid
      black_user = BlackUser.where(uid:@current_uid,black_uid: params[:uid]).first
      if black_user
        black_user.destroy
      end
      success,message = true,'移除黑名单成功'
    else
      success,message=false,'移除失败'
    end

    halt render_json({success:success,message:message})
  end

  #新鲜事设置
  def feed_page

    redirect_to_root

    set_no_cache_header

    halt_404 unless request.xhr?

    redirect_to_login("/#/personal_settings/feed") unless @current_uid

    @personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)

    halt erb_js(:feed_page_js)
  end

  #更新新鲜事设置
  def update_feed
    set_no_cache_header
    halt render_json({result: "unlogin"}) unless @current_uid
    begin
      query = {}
      query[:is_feed_comment] = params[:feed_comment].present?
      query[:is_feed_favorite] = params[:feed_favorite].present?
      query[:is_feed_following] = params[:feed_following].present?

      personal_setting = PersonalSetting.where(uid: @current_uid).first || PersonalSetting.create(uid: @current_uid)
      personal_setting.update_attributes(query)
      halt render_json({result: "success"})
    rescue
      halt render_json({result: "failure", msg: "修改失败"})
    end
  end

end