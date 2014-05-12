class TagsRoute < TagsController

  #标签详情页
  route :get, :post, '/tag/:tname.ajax'                 do dispatch(:show_page) end
  route :get, :post, '/tag/:tname'                      do dispatch(:show_page) end

  route :get, :post, '/tags/:tname.ajax'                do dispatch(:show_page) end
  route :get, :post, '/tags/:tname'                     do dispatch(:show_page) end

  route :get, :post, '/tag/:tname/show_right'           do dispatch(:show_right) end

  route :get, :post, '/tag/:tname/follower.ajax'        do dispatch(:follower_page) end
  route :get, :post, '/tag/:tname/follower'             do dispatch(:follower_page) end

  route :post,       '/tag/:tname/switch_follow'        do dispatch(:switch_follow) end


  # 去掉的路由
  # route :post,       '/following_tags/create'           do  end
  # route :post,       '/following_tags/:id/destroy'      do  end
  # route :get, :post  '/following_tags'                  do  end

end