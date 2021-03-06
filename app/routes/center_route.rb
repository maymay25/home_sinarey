
class CenterRoute < CenterController

  error do halt_500 end

  route :get, :post, '/n/:nickname.ajax'            do dispatch(:index_page) end
  route :get, :post, '/n/:nickname'                 do dispatch(:index_page) end

  route :get, :post, %r{^/([\d]+)/profile.ajax$}    do |uid| params[:uid]=uid ; dispatch(:index_page) end
  route :get, :post, %r{^/([\d]+)/profile$}         do |uid| params[:uid]=uid ; dispatch(:index_page) end
  route :get, :post, %r{^/([\d]+).ajax$}            do |uid| params[:uid]=uid ; dispatch(:index_page) end
  route :get, :post, %r{^/([\d]+)$}                 do |uid| params[:uid]=uid ; dispatch(:index_page) end

  route :get, :post, %r{^/([\d]+)/feed.ajax$}       do |uid| params[:uid]=uid ; dispatch(:get_feeds) end

  route :get, :post, '/feed/index'                  do dispatch(:get_more_feeds) end
  route :get, :post, '/feed'                        do dispatch(:get_more_feeds) end
  route :post,       '/feed/no_read'                do dispatch(:get_no_read_feed_num) end
  route :post,       '/feed/del_feed'               do dispatch(:do_del_feed) end

  route :get,        '/center/timeline_list'        do dispatch(:get_timeline_list) end

  route :get,        %r{^/([\d]+)/card$}            do |uid| params[:uid]=uid ; dispatch(:get_show_card) end


  route :get, :post, %r{^/([\d]+)/sound_ids$}       do |uid| params[:uid]=uid ; dispatch(:get_sound_ids) end
  route :get, :post, %r{^/([\d]+)/sound_list$}      do |uid| params[:uid]=uid ; dispatch(:get_sound_list) end

  route :get, :post, %r{^/([\d]+)/sound.ajax$}      do |uid| params[:uid]=uid ; dispatch(:sound_page) end
  route :get, :post, %r{^/([\d]+)/sound$}           do |uid| params[:uid]=uid ; dispatch(:sound_page) end

  route :get, :post, %r{^/([\d]+)/album.ajax$}      do |uid| params[:uid]=uid ; dispatch(:album_page) end
  route :get, :post, %r{^/([\d]+)/album$}           do |uid| params[:uid]=uid ; dispatch(:album_page) end

  route :get, :post, %r{^/([\d]+)/follow.ajax$}     do |uid| params[:uid]=uid ; dispatch(:follow_page) end
  route :get, :post, %r{^/([\d]+)/follow$}          do |uid| params[:uid]=uid ; dispatch(:follow_page) end

  route :get, :post, %r{^/([\d]+)/fans.ajax$}       do |uid| params[:uid]=uid ; dispatch(:fans_page) end
  route :get, :post, %r{^/([\d]+)/fans$}            do |uid| params[:uid]=uid ; dispatch(:fans_page) end

  route :get, :post, %r{^/([\d]+)/favorites.ajax$}  do |uid| params[:uid]=uid ; dispatch(:favorites_page) end
  route :get, :post, %r{^/([\d]+)/favorites$}       do |uid| params[:uid]=uid ; dispatch(:favorites_page) end

  route :get, :post, %r{^/([\d]+)/listened.ajax$}   do |uid| params[:uid]=uid ; dispatch(:listened_page) end
  route :get, :post, %r{^/([\d]+)/listened$}        do |uid| params[:uid]=uid ; dispatch(:listened_page) end

  route :get, :post, %r{^/([\d]+)/publish.ajax$}    do |uid| params[:uid]=uid ; dispatch(:publish_page) end
  route :get, :post, %r{^/([\d]+)/publish$}         do |uid| params[:uid]=uid ; dispatch(:publish_page) end

  # notice
  route :post,       '/notices'                     do dispatch(:get_msg_notice) end
  route :post,       '/notices/clear'               do dispatch(:do_clear_msg_notices) end

  route :get,:post,  '/quan_suggest'                do dispatch(:get_quan_suggest) end

  route :post,       '/report/create'               do dispatch(:do_create_report) end

  # podcast 申请相关
  route :get,        '/podcast/record'              do dispatch(:podcast_page) end
  route :get,        '/podcast/apply'               do dispatch(:podcast_apply_page) end
  route :get,        '/podcast/apply/:id'           do dispatch(:podcast_apply_result_page) end
  route :get,        '/podcast/apply_albums'        do dispatch(:get_podcast_apply_albums) end
  route :post,       '/podcast/create'              do dispatch(:do_create_podcast) end

end
