class UserOnWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :user_on, :retry => 0, :dead => true

  defined?(UserOnWorkerMethods) and include UserOnWorkerMethods
  
end