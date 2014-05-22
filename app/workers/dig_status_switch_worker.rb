class DigStatusSwitchWorker
  
  include Sidekiq::Worker
  sidekiq_options :queue => :dig_status_switch, :retry => 0, :dead => true

  defined?(DigStatusSwitchWorkerMethods) and include DigStatusSwitchWorkerMethods

end