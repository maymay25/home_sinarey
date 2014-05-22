
class FollowingDestroyedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :following_destroyed, :retry => 0, :dead => true

  defined?(FollowingDestroyedWorkerMethods) and include FollowingDestroyedWorkerMethods

end