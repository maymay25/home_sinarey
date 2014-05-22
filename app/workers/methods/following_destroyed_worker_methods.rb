module FollowingDestroyedWorkerMethods

  def perform(action,*args)
    method(action).call(*args)
  end

  def following_destroyed(follow_id,uid,following_uid,is_auto_push,nickname,avatar_path,following_nickname,following_avatar_path)

    old_group_ids = []
    old_group_ids << -1 if is_auto_push

    f2 = Following.stn(following_uid).where(uid: following_uid, following_uid: uid).first
    f2.update_attribute(:is_mutual, false) if f2

    Followingx2Group.stn(uid).where(uid: uid, following_id: follow_id).each do |f|
      f.destroy
      old_group_ids << f.following_group_id
    end

    $rabbitmq_channel.fanout(Settings.topic.follow.destroyed, durable: true).publish(Yajl::Encoder.encode({
      id: follow_id,
      uid: uid,
      following_uid: following_uid,
      nickname: nickname,
      avatar_path: avatar_path,
      following_nickname: following_nickname,
      following_avatar_path: following_avatar_path,
      created_at: Time.now
    }), content_type: 'text/plain', persistent: true)

    $rabbitmq_channel.fanout(Settings.topic.followgroup.changed, durable: true).publish(Yajl::Encoder.encode({
      uid: uid,
      following_uid: following_uid,
      current_following_groups: [],
      old_following_groups: old_group_ids,
      created_at: Time.now
    }), content_type: 'text/plain', persistent: true)
    
    logger.info "#{Time.now} #{uid} unfollow #{following_uid}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end


  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/following_destroyed#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end