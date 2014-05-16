class FollowController < ApplicationController

  set :views, ['follow','application']

  def dispatch(action,params_options={})
    super(:follow,action)
    method(action).call
  end

  #关注 params: following_uid
  def xhr_follow_user

    halt_400 unless @current_uid

    following_user = $profile_client.queryUserBasicInfo(params[:following_uid].to_i)

    followings_sum, limit_sum = $counter_client.get(Settings.counter.user.followings, @current_uid).to_i, 2000
    halt render_json({res: false, error: "same", msg: "关注失败，达到关注人数上限(#{limit_sum})"}) if followings_sum >= limit_sum

    halt render_json({res: false, error: "miss", msg: "该用户不存在"}) unless following_user
    
    halt render_json({res: false, error: "same", msg: "不能关注自己哦"}) if @current_uid == following_user.uid

    halt render_json({res: false, error: "blacklist", msg: "由于对方的设置，无法进行此操作"}) if BlackUser.where(uid: following_user.uid, black_uid: @current_uid).any?

    following = Following.stn(@current_uid).where(uid: @current_uid, following_uid: following_user.uid).first
    
    unless following
      follower = Follower.stn(@current_uid).where(uid: following_user.uid, following_uid: @current_uid).first
      is_mutual = !follower.nil?

      following = Following.create(uid: @current_user.uid, 
        nickname: @current_user.nickname,
        avatar_path: @current_user.logoPic,
        personal_signature: @current_user.personalSignature ? @current_user.personalSignature[0, 255] : nil,
        country: @current_user.country,
        province: @current_user.province,
        city: @current_user.city,
        town: @current_user.town,
        following_uid: following_user.uid,
        following_nickname: following_user.nickname,
        following_avatar_path: following_user.logoPic,
        following_personal_signature: following_user.personalSignature ? following_user.personalSignature[0, 255] : nil,
        following_country: following_user.country,
        following_province: following_user.province,
        following_city: following_user.city,
        following_town: following_user.town,
        following_is_v: following_user.isVerified,
        is_mutual: is_mutual
      )
      
      # 关注数 + 1
      $counter_client.incr(Settings.counter.user.followings, @current_uid, 1)

      follow_topic = []

      topic_hash = {
        id: following.id,
        uid: following.uid,
        following_uid: following.following_uid,
        nickname: following.nickname,
        avatar_path: following.avatar_path,
        personal_signature: following.personal_signature,
        country: following.country,
        province: following.province,
        city: following.city,
        town: following.town,
        following_nickname: following.following_nickname,
        following_avatar_path: following.following_avatar_path,
        following_personal_signature: following.following_personal_signature,
        following_country: following.following_country,
        following_province: following.following_province,
        following_city: following.following_city,
        following_town: following.following_town,
        following_is_v: following.following_is_v,
        following_group_id: nil,
        created_at: Time.new
      }

      current_ps = PersonalSetting.where(uid: @current_uid).first
      topic_hash[:is_feed] = current_ps.nil? || current_ps.is_feed_following==true

      follow_topic << topic_hash

      $rabbitmq_channel.fanout(Settings.topic.follow.created, durable: true).publish(Yajl::Encoder.encode(follow_topic), content_type: 'text/plain', persistent: true)
    end
    
    render_json({ res: {is_followed: true, is_mutual_followed: is_mutual, be_followed:is_mutual}, msg: print_message(:success) })
  end

  #取消关注 params: following_uid
  def xhr_cancel_follow_user

    halt_400 unless @current_uid

    destroy_follow_relation(@current_uid,params[:following_uid])

    render_json({res: true, msg: print_message(:success)})
  end

  #移除粉丝 params: uid
  def xhr_remove_follower
    halt_400 unless @current_uid

    destroy_follow_relation(params[:uid],@current_uid)

    render_json({res: true, msg: print_message(:success)})
  end

  #设置用户的分组 params: following_uid, following_group_ids[], is_auto_push
  def xhr_set_groups

    groups,res = [],{}
    
    following = Following.stn(@current_uid).where(uid: @current_uid, following_uid: params[:following_uid]).first
    if following
      group_ids = []
      old_group_ids = []
      old_is_auto_push = false

      is_auto_push_count = Following.stn(@current_uid).where(uid: @current_uid, is_auto_push: true).count
      if is_auto_push_count >= Settings.auto_push_group_limit and !following.is_auto_push and params[:is_auto_push] == 'true'
        res[:error] = "必听组好友不能超过#{Settings.auto_push_group_limit}个"
      else
        old_is_auto_push = following.is_auto_push
        
        if old_is_auto_push != params[:is_auto_push]
          following.update_attribute('is_auto_push', params[:is_auto_push])
        end

        # 必听组记 -1
        if old_is_auto_push
          old_group_ids << -1
        end

        if following.is_auto_push
          groups << '必听组'
          group_ids << -1
        end
      end
      
      # 先全部删除
      Followingx2Group.stn(@current_uid).where(uid: @current_uid, following_id: following.id).each do |f|
        f.destroy
        old_group_ids << f.following_group_id
      end

      if params[:following_group_ids]
        params[:following_group_ids].uniq.each do |fg_id|
          fx2_count = Followingx2Group.stn(@current_uid).where(uid: @current_uid, following_group_id: fg_id).count
          if fx2_count >= Settings.following_group_limit
            res[:error] = "分组好友不能超过#{Settings.following_group_limit}个"
          else
            fg = FollowingGroup.stn(@current_uid).where(id: fg_id).first
            if fg
              Followingx2Group.create(uid: @current_uid, following_id: following.id, following_group_id: fg.id, following_uid: following.following_uid)
              groups << fg.title
              group_ids << fg.id
            end
          end
          
        end
      end

      $rabbitmq_channel.fanout(Settings.topic.followgroup.changed, durable: true).publish(Yajl::Encoder.encode({
        uid: following.uid,
        following_uid: following.following_uid,
        current_following_groups: group_ids,
        old_following_groups: old_group_ids,
        created_at: Time.new
      }), content_type: 'text/plain', persistent: true)
    end

    res[:groups] = cut_groups(groups)
    res[:res] = res[:error] ? false : true

    render_json(res)
  end

  #关注分组相关

  def get_following_groups

    set_no_cache_header

    halt_400 unless @current_uid

    fgs = []
    all_groups = FollowingGroup.stn(@current_uid).where(uid: @current_uid)
    all_groups.each do |fg| 
      fgs << {id: fg.id, title: fg.title}
    end
    render_json(fgs)
  end

  # params: title
  def xhr_create_following_group

    halt render_json({res: false, errno: "following_groups.1", msg: print_message(:params_missing, "current uid")}) unless @current_uid

    halt render_json({res: false, errno: "following_groups.2", msg: print_message(:params_missing, "title")}) if params[:title].blank?
    
    halt render_json({res: false, errno: "following_groups.3", msg: "分组最多创建16个"}) if !@current_user.isVerified and FollowingGroup.stn(@current_uid).where(uid: @current_uid).count >= 16

    title = CGI.escapeHTML(params[:title].strip)

    fg = FollowingGroup.stn(@current_uid).where(uid: @current_uid, title: title).first
    halt render_json({res: false, errno: "following_groups.4", msg: "#{params[:title].strip} 已存在"})
    
    fg = FollowingGroup.create(uid: @current_uid, title: title)
    render_json({ id: fg.id })
  end

  # params: id, title
  def xhr_update_following_group

    halt render_json({res: false, errno: "following_groups.1", msg: print_message(:params_missing, "current uid")}) unless @current_uid

    halt render_json({res: false, errno: "following_groups.2", msg: print_message(:params_missing, "title")}) if params[:title].blank?

    id,title = params[:id].to_i,CGI.escapeHTML(params[:title].strip)

    already_exist = FollowingGroup.stn(@current_uid).where('id <> ? and title = ? and uid = ?', id, title, @current_uid).any?
    halt render_json({res: false, errno: "following_groups.4", msg: "#{title}分组已经存在"}) if already_exist

    fg = FollowingGroup.stn(@current_uid).where(id: id).first
    if fg and fg.title != title
      fg.title = title
      fg.save
    end

    render_json({res: true, msg: print_message(:success)})
  end

  # params: id
  def xhr_destroy_following_group

    halt render_json({res: false, error: "unlogin", msg: print_message(:params_missing, "current uid")}) unless @current_uid

    following_ids = []

    fg = FollowingGroup.stn(@current_uid).where(id: params[:id]).first
    fg.destroy
    Followingx2Group.stn(@current_uid).where(uid: @current_uid, following_group_id: fg.id).each do |f|
      f.destroy
      following_ids << f.following_id
    end

    following_uids = Following.stn(@current_uid).where(uid: @current_uid, id: following_ids).select('following_uid').collect{|f| f.following_uid}

    $rabbitmq_channel.fanout(Settings.topic.followgroup.destroyed, durable: true).publish(Yajl::Encoder.encode({
      uid: @current_uid,
      group_id: fg.id,
      following_uids: following_uids,
      created_at: Time.new
    }), content_type: 'text/plain', persistent: true)
      
    render_json({res: true, msg: print_message(:success)})
  end


  private

  def destroy_follow_relation(uid,uid2)
    following = Following.stn(uid).where(uid: uid, following_uid: uid2).first
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
  end

end