class AlbumUpdatedWorker
  
  include Sidekiq::Worker
  sidekiq_options :queue => :album_updated, :retry => 0, :dead => true

  defined?(AlbumUpdatedWorkerMethods) and include AlbumUpdatedWorkerMethods

end