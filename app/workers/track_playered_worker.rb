
class TrackPlayedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :track_played, :retry => 0, :dead => true

  defined?(TrackPlayedWorkerMethods) and include TrackPlayedWorkerMethods

end