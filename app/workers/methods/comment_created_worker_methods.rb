module CommentCreatedWorkerMethods

  include ApnDispatchHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def comment_created(comment_id,track_id,pid,mid,sharing_to,dotcom)
    comment = Comment.stn(track_id).where(id: comment_id).first
    comment_user = $profile_client.queryUserBasicInfo(comment.uid)
    track = Track.stn(comment.track_id).where(id: comment.track_id).first
    
    quan_ignores = [comment_user.nickname]

    if pid.to_s!=""
      # 回复评论
      pcomment = Comment.stn(comment.track_id).where(id: pid).first
      pcomment_user = $profile_client.queryUserBasicInfo(pcomment.uid)
      # 父评论作者收件箱 评论我的
      Inbox.create(uid: comment.uid,
        nickname: comment_user.nickname,
        to_uid: pcomment_user.uid,
        to_nickname: pcomment_user.nickname,
        message_type: 3,
        content: comment.content,
        track_id: track.id, 
        track_title: track.title, 
        track_cover_path: track.cover_path,
        track_uid: track.uid, 
        track_nickname: track.nickname, 
        comment_id: comment.id, 
        second: comment.second,
        pcomment_id: mid, 
        pcomment_content: pcomment.content[0..500],
        avatar_path: comment_user.logoPic,
        extra_json: { track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
          track_uid: track.uid, track_nickname: track.nickname, comment_id: comment.id, second: comment.second, 
          pcomment_id: mid, pcomment_content: pcomment.content[0, 100] }.to_json,
        to_avatar_path: pcomment.avatar_path
      )
      if pcomment.uid != comment.uid
        ps = PersonalSetting.where(uid: pcomment.uid).first
        is_notice = ps ? ps.notice_quan : true
        pcomment_user_dj = pcomment_user if is_notice
      end
      quan_ignores << pcomment_user.nickname
    end # -- if pid

     # 评论者不是声音发布者，且声音发布者不是父评论作者
    if comment.uid != track.uid and (pcomment_user.nil? or pcomment_user.uid != track.uid)
      # 声音发布者 收件箱 收到一条评论我的
      track_user = $profile_client.queryUserBasicInfo(track.uid)

      Inbox.create(uid: comment.uid,
        nickname: comment_user.nickname,
        to_uid: track_user.uid,
        to_nickname: track_user.nickname,
        message_type: 2,
        content: comment.content,
        track_id: track.id, 
        track_title: track.title, 
        track_cover_path: track.cover_path,
        track_uid: track.uid, 
        track_nickname: track.nickname, 
        comment_id: comment.id, 
        second: comment.second,
        avatar_path: comment_user.logoPic,
        extra_json: { track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
          track_uid: track.uid, track_nickname: track.nickname, comment_id: comment.id, second: comment.second }.to_json,
        to_avatar_path: track.avatar_path
      )
      if track.uid != comment.uid
        track_ps = PersonalSetting.where(uid: track.uid).first
        is_notice = track_ps ? track_ps.notice_comment : true
        track_user_dj = track_user if is_notice
      end
      quan_ignores << track_user.nickname
    end
    # 圈到的
    refer_names = select_names(comment.content)
    if refer_names.size > 0
      refer_users_dj = []
      refer_users_push_dj = []
      refer_names.uniq.each do |refer_name|
        next if quan_ignores.include?(refer_name)
        refer_users = $profile_client.getProfileByNickname(refer_name)
        next if refer_users.empty?
        u = refer_users.first
        # 黑名单
        next if BlackUser.where(uid:u.uid,black_uid:comment_user.uid).first
        ps = PersonalSetting.where(uid: u.uid).first
        if ps
          ignored = case ps.allow_at_me_content
          when 2
            true if !comment_user.isVerified and !Following.stn(u.uid).where(uid: u.uid, following_uid: comment_user.uid).any? and !Follower.stn(u.uid).where(uid: comment_user.uid, following_uid: u.uid).any?
          when 3
            true unless Following.stn(u.uid).where(uid: u.uid, following_uid: comment_user.uid).any?
          when 4
            true
          else
            false
          end
        else
          ignored = false
        end
        next if ignored
        Inbox.create(uid: comment_user.uid,
          nickname: comment_user.nickname,
          to_uid: u.uid,
          to_nickname: u.nickname,
          message_type: 4,
          content: comment.content,
          track_id: track.id, 
          track_title: track.title, 
          track_cover_path: track.cover_path,
          track_uid: track.uid, 
          track_nickname: track.nickname, 
          comment_id: comment.id, 
          second: comment.second,
          extra_json: { 
            track_id: track.id, track_title: track.title, track_cover_path: track.cover_path, 
            track_uid: track.uid, track_nickname: track.nickname, comment_id: comment.id, second: comment.second
          }.to_json,
          avatar_path: comment_user.logoPic,
          to_avatar_path: u.middlePic
        )
        is_notice = ps ? ps.notice_quan : true

        refer_users_dj << u if is_notice
        refer_users_push_dj << u
      end # -- do |refer_name|
    end # -- if refer_names.size > 0

    # other jobs
    if pcomment_user_dj
      $counter_client.incr(Settings.counter.user.new_comment, pcomment_user_dj.uid, 1)
    end

    if pcomment_user
      dispatch_comment(3, pcomment_user, comment)
    end

    if track_user_dj
      $counter_client.incr(Settings.counter.user.new_comment, track_user_dj.uid, 1)
    end

    if track_user
      dispatch_comment(2, track_user, comment)
    end

    if refer_users_dj and refer_users_dj.size > 0
      refer_users_dj.each do |u|
        $counter_client.incr(Settings.counter.user.new_quan, u.uid, 1)
      end
    end

    if refer_users_push_dj and refer_users_push_dj.size > 0
      refer_users_push_dj.each_index do |index|
        dispatch_comment(4, refer_users_push_dj[index], comment)
      end
    end

    if sharing_to
      comment_content = comment.content.gsub('@',' ') if !comment.content.nil?
      message = {syncType: 'comment', cleintType:'web', uid: comment.uid.to_s, thirdpartyNames:sharing_to, title: track.title, summary: track.intro, comment: "“#{cut_str(comment.content, 100, '...')}” 我正在听《#{track.title}》", url: "#{dotcom}/#{track.uid}/sound/#{track.id}", images: file_url(track.cover_path)}
      $rabbitmq_channel.queue('thirdparty.feed.queue', durable: true).publish(Yajl::Encoder.encode(message), content_type: 'text/plain')
    end

    hash = comment.attributes
    hash.delete('id')
    hash.delete('created_at')
    comment_origin = CommentOrigin.where(id: comment.id).first
    if comment_origin.nil?
      comment_origin = CommentOrigin.new
      comment_origin.id = comment.id
      comment_origin.created_at = comment.created_at
    end
    comment_origin.update_attributes(hash)
    
    res = HIGHRISKWORD_SERVICE.dangerWordChecker(5, comment.content)
    uag = UidApproveGroup.where(uid: comment.uid).first

    if res.wordsAndScore.empty?
      #评论审核2.0
      ApprovingComment.create(comment_id: comment.id,
        approve_group_id: uag ? uag.approve_group_id : nil,
        uid: comment.uid,
        nickname: comment.nickname,
        track_id: comment.track_id,
        track_title: comment.track_title,
        track_cover_path: comment.cover_path,
        second: comment.second,
        parent_id: comment.parent_id,
        content: comment.content,
        upload_source: comment.upload_source,
        comment_created_at: comment.created_at
      )
    else
      words = []
      res.wordsAndScore.each do |k,v|
        words << k
      end

      ApprovingHighriskword.create(comment_id: comment.id,
        approve_group_id: uag ? uag.approve_group_id : nil,
        uid: comment.uid,
        nickname: comment.nickname,
        track_id: comment.track_id,
        track_title: comment.track_title,
        track_cover_path: comment.cover_path,
        second: comment.second,
        parent_id: comment.parent_id,
        content: comment.content,
        upload_source: comment.upload_source,
        comment_created_at: comment.created_at,
        high_risk_word: words.join(",")
      )
    end

    logger.info "#{Time.now} #{comment_id} #{track_id}"
  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/comment_created#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end