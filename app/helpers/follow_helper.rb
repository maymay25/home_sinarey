module FollowHelper

  def destroy_follow_relation(uid,uid2)
    flw = Following.shard(uid).where(uid: uid, following_uid: uid2).first
    if flw
      flw.destroy
      async_args = [flw.id,flw.uid,flw.following_uid,flw.is_auto_push,flw.nickname,flw.avatar_path,flw.following_nickname,flw.following_avatar_path]
      CoreAsync::FollowingDestroyedWorker.perform_async(:following_destroyed,*async_args)
    end
  end

end