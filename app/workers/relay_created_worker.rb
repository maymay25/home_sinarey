class RelayCreatedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :relay_created, :retry => 0, :dead => true

  defined?(RelayCreatedWorkerMethods) and include RelayCreatedWorkerMethods

end