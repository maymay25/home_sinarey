
class FollowingCreatedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :following_created, :retry => 0, :dead => true

  defined?(FollowingCreatedWorkerMethods) and include FollowingCreatedWorkerMethods

end