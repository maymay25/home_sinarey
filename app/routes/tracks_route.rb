
class TracksRoute < TracksController

  # 声音详细页
  route :get, :post, %r{^/([\d]+)/sound/([\d]+).ajax$}       do |uid,id| dispatch(:show_page,uid:uid,id:id) end
  route :get, :post, %r{^/([\d]+)/sound/([\d]+)$}            do |uid,id| dispatch(:show_page,uid:uid,id:id) end

  #声音喜欢者页
  route :get, :post, %r{^/([\d]+)/sound/([\d]+)/liker.ajax$} do |uid,id| dispatch(:liker_page,uid:uid,id:id) end
  route :get, :post, %r{^/([\d]+)/sound/([\d]+)/liker$}      do |uid,id| dispatch(:liker_page,uid:uid,id:id) end

  route :get, :post, %r{^/sounds/([\d]+)/rich_intro$}        do |id| dispatch(:rich_intro_template,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/maybe_like_list$}   do |id| dispatch(:maybe_like_list_template,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/comment_list$}      do |id| dispatch(:track_comment_list_template,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/relay_list$}        do |id| dispatch(:track_relay_list_template,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/right$}             do |id| dispatch(:right_template,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/pictures$}          do |id| dispatch(:get_pictures,id:id) end
  route :get, :post, %r{^/sounds/([\d]+)/expend_box$}        do |id| dispatch(:expend_box_template,id:id) end

  route :get, :post, '/sounds/comment_list_template'         do dispatch(:feed_comment_list_template) end
  route :get, :post, '/sounds/relay_list_template'           do dispatch(:feed_relay_list_template) end

  route :get, :post, %r{^/sound/([\d]+)$}                    do |id| dispatch(:track_show0,id:id) end

  route :post,       %r{^/tracks/([\d]+)/play$}              do |id| dispatch(:do_play_track,id:id) end

  route :post,       %r{^/my_tracks/([\d]+)/destroy$}        do |record_id| dispatch(:do_destroy_track,record_id:record_id) end

  route :get, :post, '/track_blocks/avatars'                 do dispatch(:get_track_blocks_avatars) end

  route :get, :post, %r{^/tracks/([\d]+)$}                   do |id| dispatch(:track_show0,id:id) end
  route :get, :post, %r{^/tracks/([\d]+).json$}              do |id| dispatch(:get_track_json,id:id) end # 声音json
  route :get, :post, '/tracks/:ids.infos'                    do dispatch(:get_multi_tracks_json) end # 多个声音json 1_2_3.infos

  route :get, :post, %r{^/tracks/([\d]+)/([\d]+)$}           do |track_id,block_idx| dispatch(:get_track_blocks_comments,track_id:track_id,block_idx:block_idx) end # 根据track_id和块拿评论 

  route :post,       '/favorites/create'                     do dispatch(:do_like_track) end
  route :post,       '/favorites/destroy'                    do dispatch(:cancel_like_track) end

  route :post,       '/handle_track/relay'                   do dispatch(:do_relay_track) end
  route :post,       '/handle_track/set_public'              do dispatch(:do_set_public) end # 私密声音转公开
  route :post,       '/handle_track/join_album'              do dispatch(:do_join_album) end # 添加到专辑
  route :post,       '/handle_track/album_list'              do dispatch(:get_album_list) end # 可选专辑列表

  route :get, :post, %r{^/edit_track/([\d]+)$}               do |id| dispatch(:edit_page,id:id) end
  route :post,       %r{^/edit_track/([\d]+)/update$}        do |id| dispatch(:do_update_track,id:id) end

  #上传声音相关
  route :get, :post, '/upload'                               do dispatch(:upload_page) end
  route :post,       '/upload/create'                        do dispatch(:do_dispatch_upload) end

  route :get, :post, '/upload/choose_album'                  do dispatch(:get_album_choose_list_partial) end #上传·选择声音模块
  route :get, :post, '/upload/valid_code_partial'            do dispatch(:get_valid_code_partial) end # 验证码局部页
  
  route :get, :post, '/upload/valid_code_json'               do dispatch(:get_valid_code_json) end #验证码json

end
