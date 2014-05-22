class MessageCreatedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :message_created, :retry => 0, :dead => true

  defined?(MessageCreatedWorkerMethods) and include MessageCreatedWorkerMethods

end