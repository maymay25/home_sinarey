module MessageCreatedWorkerMethods

  include ApnDispatchHelper

  def perform(action,*args)
    method(action).call(*args)
  end

  def message_created(uid,chat_id)

    chat = Chat.stn(uid).where(id: chat_id).first

    return if BlackUser.where(uid: chat.with_uid, black_uid: uid).any?

    to_ps = PersonalSetting.where(uid: chat.with_uid).first

    is_notice = to_ps ? to_ps.notice_message : true

    $counter_client.incr(Settings.counter.user.new_message, chat.with_uid, 1) if is_notice
  
    dispatch_letter(chat)

    # 小编聊天
    editor = Editor.where(uid: chat.uid).first
    if editor
      EditorChat.create(is_in: false, uid: editor.uid, with_uid: chat.with_uid, with_nickname: chat.with_nickname, content: chat.content)
    end

    with_editor = Editor.where(uid: chat.with_uid).first
    if with_editor
      EditorChat.create(is_in: true, uid: with_editor.uid, with_uid: chat.uid, with_nickname: chat.nickname, content: chat.content)
    end

    logger.info "#{Time.now} #{uid} #{chat_id}"

  rescue Exception => e
    logger.error "#{Time.now} #{e.class}: #{e.message} \n #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def logger
    current_day = Time.now.strftime('%Y-%m-%d')
    if (@@day||=nil) != current_day
      @@logger = ::Logger.new(Sinarey.root+"/log/sidekiq/message_created#{current_day}.log")
      @@logger.level = Logger::INFO
      @@day = current_day
    end
    @@logger
  end

end