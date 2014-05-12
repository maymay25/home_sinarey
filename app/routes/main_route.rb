
class MainRoute < MainController

  route :get,        '/'                            do dispatch(:index) end

  route :get, :post, '/global_counts_json'          do dispatch(:global_counts_json) end

  route :get, :post, '/sitemap/silian_sound.txt'    do dispatch(:silian_sound) end

  route :get, :post, '/sitemap/silian_album.txt'    do dispatch(:silian_album) end

  route :get, :post, '/sitemap/silian_u.txt'        do dispatch(:silian_user) end

  route :get, :post, '/error_page.ajax'             do dispatch(:error_page) end
  route :get, :post, '/error_page'                  do dispatch(:error_page) end


end
