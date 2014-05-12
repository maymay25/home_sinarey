
class MsgcenterRoute < MsgcenterController

  #系统通知
  route :get, :post, '/msgcenter/notice.ajax'                   do dispatch(:notice_page) end 
  route :get, :post, '/msgcenter/notice'                        do dispatch(:notice_page) end
  route :post,       '/msgcenter/destroy_notice'                do dispatch(:destroy_notice) end

  #圈我的消息
  route :get, :post, '/msgcenter/referme.ajax'                  do dispatch(:referme_page) end
  route :get, :post, '/msgcenter/referme'                       do dispatch(:referme_page) end

  #评论
  route :get, :post, '/msgcenter/comment.ajax'                  do dispatch(:comment_page) end
  route :get, :post, '/msgcenter/comment'                       do dispatch(:comment_page) end
  route :post,       '/msgcenter/create_comment'                do dispatch(:create_comment) end
  route :post,       '/msgcenter/destroy_comment'               do dispatch(:destroy_comment) end
  route :post,       '/comments/create'                         do dispatch(:create_comment) end
    
  route :post,       '/tracks/:track_id/comments/:comment_id/destroy' do dispatch(:destroy_comment) end

  #私信
  route :get, :post, '/msgcenter/letter.ajax'                   do dispatch(:letter_page) end
  route :get, :post, '/msgcenter/letter'                        do dispatch(:letter_page) end
  route :post,       '/msgcenter/create_letter'                 do dispatch(:create_letter) end
  route :post,       '/msgcenter/destroy_letter'                do dispatch(:destroy_letter) end
  route :post,       '/msgcenter/destroy_letter_with_uid'       do dispatch(:destroy_letter_with_uid) end
  route :post,       '/msgcenter/batch_destroy_letter'          do dispatch(:batch_destroy_letter) end

  #私信详情
  route :get, :post, %r{^/letter/([\d]+).ajax$}                 do |uid| params[:uid]=uid ;  dispatch(:letter_show) end
  route :get, :post, %r{^/letter/([\d]+)$}                      do |uid| params[:uid]=uid ;  dispatch(:letter_show) end

  #赞通知
  route :get, :post, '/msgcenter/like.ajax'                     do dispatch(:like_page) end
  route :get, :post, '/msgcenter/like'                          do dispatch(:like_page) end
  route :post,       '/msgcenter/destroy_like'                  do dispatch(:destroy_like) end

end
