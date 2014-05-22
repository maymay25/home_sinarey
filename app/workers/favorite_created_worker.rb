
class FavoriteCreatedWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :favorite_created, :retry => 0, :dead => true

  defined?(FavoriteCreatedWorkerMethods) and include FavoriteCreatedWorkerMethods

end