
class ExploreRoute < ExploreController


  route :get, :post, '/explore.ajax'             do dispatch(:index_page) end
  route :get, :post, '/explore'                  do dispatch(:index_page) end

  route :get, :post, '/go2explore.ajax'          do dispatch(:index_page) end

  route :get, :post, '/explore/sound.ajax'       do dispatch(:sound_page) end
  route :get, :post, '/explore/sound'            do dispatch(:sound_page) end
  route :get, :post, '/explore/track_list'       do dispatch(:sound_detail) end


  route :get, :post, '/explore/album.ajax'       do dispatch(:album_page) end
  route :get, :post, '/explore/album'            do dispatch(:album_page) end
  route :get, :post, '/explore/album_detail'     do dispatch(:album_detail) end

  route :get, :post, '/explore/u.ajax'           do dispatch(:user_page) end
  route :get, :post, '/explore/u'                do dispatch(:user_page) end
  route :get, :post, '/explore/user_detail'      do dispatch(:user_detail) end

  route :get, :post, '/explore/follow_status'    do dispatch(:get_follow_status) end

end
