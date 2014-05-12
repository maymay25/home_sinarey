
class AlbumsRoute < AlbumsController

  # 专辑详细页
  route :get, :post, %r{^/([\d]+)/album/([\d]+).ajax$}       do |uid,id| dispatch(:show_album_page,uid:uid,id:id) end
  route :get, :post, %r{^/([\d]+)/album/([\d]+)$}            do |uid,id| dispatch(:show_album_page,uid:uid,id:id) end

  route :get, :post, %r{^/album/([\d]+)/show_right$}         do |id| dispatch(:show_right,id:id) end

  route :get, :post, '/new_album'                            do dispatch(:new_album_page) end  # 新建专辑页面

  route :post,       '/new_album/create'                     do dispatch(:do_create_album) end #创建专辑

  route :get, :post, %r{^/edit_album/([\d]+)$}               do |id| dispatch(:edit_album_page,id:id) end # 编辑专辑页面

  route :post,       %r{^/edit_album/([\d]+)/update$}       do |id| dispatch(:do_update_album,id:id) end # 更新专辑

  route :post,       %r{^/my_albums/([\d]+)/destroy$}        do |id| dispatch(:do_destroy_album,id:id) end # 删除专辑

  route :get, :post, '/handle_album/recommend_tags'          do dispatch(:get_recommend_tags) end  # 推荐标签

  route :get, :post, '/handle_album/sound_list'              do dispatch(:get_outside_sound_list) end  # 未添加进专辑的声音列表


end
