class FollowRoute < FollowController

  #关注状态
  route :post,       '/followings/create'             do dispatch(:xhr_follow_user) end #关注
  route :post,       '/followings/destroy'            do dispatch(:xhr_cancel_follow_user) end #取消关注
  route :post,       '/followers/destroy'             do dispatch(:xhr_remove_follower) end #移除粉丝
  #route :post,       '/followings/group_create'       do  end #批量关注
  
  #设置分组
  route :post,      '/followings/set_groups'          do dispatch(:xhr_set_groups) end # 设置分组

  #关注分组记录 增删改查
  route :get,:post, '/following_groups'               do dispatch(:get_following_groups) end # 我的关注分组列表
  route :post,      '/following_groups/create'        do dispatch(:xhr_create_following_group) end # 创建关注分组
  route :post,      '/following_groups/:id/update'    do dispatch(:xhr_update_following_group) end # 更新关注分组
  route :post,      '/following_groups/:id/destroy'   do dispatch(:xhr_destroy_following_group) end # 删除关注分组

end