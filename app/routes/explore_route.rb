
class ExploreRoute < ExploreController


  route :get, :post, '/explore.ajax'             do index end
  route :get, :post, '/explore'                  do index end

  route :get, :post, '/go2explore.ajax'          do index end

  route :get, :post, '/explore/sound.ajax'       do sound_page end
  route :get, :post, '/explore/sound'            do sound_page end
  route :get, :post, '/explore/track_list'       do sound_detail end


  route :get, :post, '/explore/album.ajax'       do album_page end
  route :get, :post, '/explore/album'            do album_page end
  route :get, :post, '/explore/album_detail'     do album_detail end

  route :get, :post, '/explore/u.ajax'           do user_page end
  route :get, :post, '/explore/u'                do user_page end
  route :get, :post, '/explore/user_detail'      do user_detail end




  # 新版发现

  # match 'explore/category_list',to: 'explore#explore_category_list', via: [:get,:post]
  # match 'explore/album_list',to: 'explore#explore_album_list', via: [:get,:post]
  # match 'explore/user_list',to: 'explore#explore_user_list', via: [:get,:post]
  # match 'explore/tag_list',to: 'explore#explore_tag_list', via: [:get,:post]
  # match 'explore.ajax',to: 'explore#index', via: [:get,:post]
  # match 'explore',to: 'explore#index', via: [:get,:post]
  # match 'explore/user_detail',to: 'explore#user_detail', via: [:get,:post]
  # match 'explore/album_detail',to: 'explore#album_detail', via: [:get,:post]

end
