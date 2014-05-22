class BackendWorker
  
  include Sidekiq::Worker
  sidekiq_options :queue => :backend, :retry => 0, :dead => true

  defined?(BackendWorkerMethods) and include BackendWorkerMethods

end