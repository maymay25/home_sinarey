class MessagesSendWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :messages_send, :retry => 0, :dead => true

  defined?(MessagesSendWorkerMethods) and include MessagesSendWorkerMethods

end