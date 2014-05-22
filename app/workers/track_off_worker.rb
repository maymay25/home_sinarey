class TrackOffWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :track_off, :retry => 0, :dead => true

  defined?(TrackOffWorkerMethods) and include TrackOffWorkerMethods

end