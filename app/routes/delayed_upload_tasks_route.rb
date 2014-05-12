
class DelayedUploadTasksRoute < DelayedUploadTasksController

  route :post,       '/my_publish_tracks_and_album/destroy'  do dispatch(:get_my_publish_tracks_and_album) end

  route :get, :post, '/publish_report_message'               do dispatch(:publish_report_message) end
  route :get, :post, %r{^/delayed_tracks/([\d]+).json$}      do dispatch(:get_delayed_track_json) end

end
