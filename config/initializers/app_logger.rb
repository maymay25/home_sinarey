def new_app_logger!(nr='')
  $app_logger = ::Logger.new(Sinarey.root+"/log/#{Sinarey.env}#{nr}.log",'daily')
  $app_logger.level = Logger::INFO
end

new_app_logger!
