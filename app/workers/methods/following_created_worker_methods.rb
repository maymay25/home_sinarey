module FollowingCreatedWorkerMethods

  include ApnDispatchHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def following_created(follow_list)

    notice_uids = []

    if follow_list.size > 0
      first_msg = follow_list.first
      first_uid = first_msg['uid']
    end
    
    follow_list.each do |msg|

      current_uid,following_uid = msg['uid'],msg['following_uid']

      # 人的粉丝数
      $counter_client.incr(Settings.counter.user.followers, following_uid, 1)
      
      # 更新对方的相互关注
      f2 = Following.stn(following_uid).where(uid: following_uid, following_uid: current_uid).first
      f2.update_attribute(:is_mutual, true) if f2

      fps = PersonalSetting.where(uid: following_uid).first
      if fps
        notice_uids << following_uid if fps.notice_fan
      else
        notice_uids << following_uid 
      end
    end

    # 新粉丝
    notice_uids.each do |uid|
      $counter_client.incr(Settings.counter.user.new_follower, uid, 1)
    end

    follow_list.each do |msg|
      dispatch_follow(msg)
    end

    logger.info "#{Time.now} #{first_uid} #{notice_uids.inspect}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/following_created#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end