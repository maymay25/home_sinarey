class AlbumResendWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :album_resend, :retry => 0, :dead => true

  defined?(AlbumResendWorkerMethods) and include AlbumResendWorkerMethods

end