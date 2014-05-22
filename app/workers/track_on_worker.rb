
class TrackOnWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :track_on, :retry => 0, :dead => true

  defined?(TrackOnWorkerMethods) and include TrackOnWorkerMethods

end