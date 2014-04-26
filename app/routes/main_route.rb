
class MainRoute < MainController

  route :get,        '/'                            do index end

  route :get, :post, '/global_counts_json'          do global_counts_json end

  route :get, :post, '/sitemap/silian_sound.txt'    do silian_sound end

  route :get, :post, '/sitemap/silian_album.txt'    do silian_album end

  route :get, :post, '/sitemap/silian_u.txt'        do silian_user end

end
