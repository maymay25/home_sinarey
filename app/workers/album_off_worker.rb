class AlbumOffWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :album_off, :retry => 0, :dead => true

  defined?(AlbumOffWorkerMethods) and include AlbumOffWorkerMethods

end