
class CommentCreatedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :comment_created, :retry => 0, :dead => true

  defined?(CommentCreatedWorkerMethods) and include CommentCreatedWorkerMethods

end