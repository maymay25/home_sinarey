module FollowHelper

  def destroy_follow_relation(uid,uid2)
    follow = Following.shard(uid).where(uid: uid, following_uid: uid2).first
    if follow
      follow.destroy
      async_args = [follow.id,follow.uid,follow.following_uid,follow.is_auto_push]
      CoreAsync::FollowingDestroyedWorker.perform_async(:following_destroyed,*async_args)
    end
  end

end