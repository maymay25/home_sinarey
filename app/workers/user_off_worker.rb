class UserOffWorker
  
  include Sidekiq::Worker
  sidekiq_options :queue => :user_off, :retry => 0, :dead => true

  defined?(UserOffWorkerMethods) and include UserOffWorkerMethods

end