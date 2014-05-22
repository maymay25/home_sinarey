module MessagesSendWorkerMethods

  include CoreHelper

  def perform(action,*args)
    method(action).call(*args)
  end

    # type --- 1:粉丝 /2:选人 /3:全体非机器人主播
    # to_uids --- 选人的场合，接收者id数组
  def messages_send(type,content,uid,to_uids)

    return if ![1,2,3].include?(type) or content.blank? or uid.blank?

    to_uids = Array.wrap(to_uids)

    zhubo = $profile_client.queryUserBasicInfo(uid)

    method_time = Time.now
    if type == 1
      offset = 0
      loop do
        loop_size = 1000
        followers = Follower.stn(zhubo.uid).where(following_uid: zhubo.uid).offset(offset).limit(loop_size)
        break if followers.blank?
        followers.each do |follower|
          linkman = Linkman.stn(follower.uid).where(uid: follower.uid, linkman_uid: zhubo.uid).first
          if linkman
            linkman.no_read_count = linkman.no_read_count + 1
            linkman.last_chat_at = method_time
            linkman.last_chat_content = content
            linkman.save
          else
            Linkman.create(uid: follower.uid, 
              nickname: follower.nickname,
              avatar_path: follower.avatar_path,
              linkman_uid: zhubo.uid,
              linkman_nickname: zhubo.nickname,
              linkman_avatar_path: zhubo.logoPic,
              no_read_count: 1,
              last_chat_at: method_time,
              last_chat_content: content
            )
          end

          Chat.create(uid: follower.uid,
            nickname: follower.nickname,
            avatar_path: follower.avatar_path,
            with_uid: zhubo.uid,
            with_nickname: zhubo.nickname,
            with_avatar_path: zhubo.logoPic,
            is_in: true,
            content: content,
            upload_source: 2)
          $counter_client.incr(Settings.counter.user.new_message, follower.uid, 1)
        end
        offset += loop_size
      end
    elsif type == 2
      to_uids.each do |to_uid|
        to_user = PROFILE_SERVICE.queryUserBasicInfo(to_uid)

        linkman = Linkman.stn(to_user.uid).where(uid: to_user.uid, linkman_uid: zhubo.uid).first
        if linkman
          linkman.no_read_count = linkman.no_read_count + 1
          linkman.last_chat_at = method_time
          linkman.last_chat_content = content
          linkman.save
        else
          Linkman.create(uid: to_user.uid, 
            nickname: to_user.nickname,
            avatar_path: to_user.logoPic,
            linkman_uid: zhubo.uid,
            linkman_nickname: zhubo.nickname,
            linkman_avatar_path: zhubo.logoPic,
            no_read_count: 1,
            last_chat_at: method_time,
            last_chat_content: content
          )
        end

        chat = Chat.create(uid: to_user.uid,
          nickname: to_user.nickname,
          avatar_path: to_user.logoPic,
          with_uid: zhubo.uid,
          with_nickname: zhubo.nickname,
          with_avatar_path: zhubo.logoPic,
          is_in: true,
          content: content,
          upload_source: 2)

        unless BlackUser.where(uid: to_user.uid, black_uid: zhubo.uid).any?
          # 新私信计数 和 推送
          to_ps = PersonalSetting.where(uid: to_user.uid).first
          is_notice = to_ps ? to_ps.notice_message : true

          $counter_client.incr(Settings.counter.user.new_message, to_user.uid, 1) if is_notice
        
          $rabbitmq_channel.queue('pns-standard-server.unicastmessage.queue', durable: true).publish(Yajl::Encoder.encode({
            type: 5, 
            to_uid: to_user.uid,
            id: chat.id,
            content: content,
            from_uid: zhubo.uid,
            from_nickname: zhubo.nickname,
            badge: get_badge(to_user.uid),
            message_content: "\"#{zhubo.nickname}\"给您发来私信:#{content}"
          }), content_type: 'text/plain')
          logger.info "#{Time.now} #{to_user.uid} pushed"
          # end

        end
      end
    elsif type == 3
      offset = 0
      loop do
        vusers = VUser.where(true).offset(offset).limit(1000)
        break if vusers.count == 0
        vusers.each do |vuser|
          linkman = Linkman.stn(vuser.uid).where(uid: vuser.uid, linkman_uid: zhubo.uid).first
          if linkman
            linkman.no_read_count = linkman.no_read_count + 1
            linkman.last_chat_at = method_time
            linkman.last_chat_content = content
            linkman.save
          else
            Linkman.create(uid: vuser.uid, 
              nickname: vuser.nickname,
              avatar_path: vuser.avatar_path,
              linkman_uid: zhubo.uid,
              linkman_nickname: zhubo.nickname,
              linkman_avatar_path: zhubo.logoPic,
              no_read_count: 1,
              last_chat_at: method_time,
              last_chat_content: content
            )
          end
        
          Chat.create(uid: vuser.uid,
            nickname: vuser.nickname,
            avatar_path: vuser.avatar_path,
            with_uid: zhubo.uid,
            with_nickname: zhubo.nickname,
            with_avatar_path: zhubo.logoPic,
            is_in: true,
            content: content,
            upload_source: 2)
          $counter_client.incr(Settings.counter.user.new_message, vuser.uid, 1)
        end
        offset += 1000
      end
    end

    logger.info "#{Time.now} #{type},#{content},#{uid},#{to_uids.size}}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end



  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/messages_send#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end