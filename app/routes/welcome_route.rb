
class WelcomeRoute < WelcomeController

  route :get, :post, '/help/aboutus'                do dispatch(:about_us_page) end
  route :get, :post, '/help/contact_us'             do dispatch(:contact_us_page) end
  route :get, :post, '/help/official_news'          do dispatch(:official_news_page) end
  route :get, :post, '/help/join_us'                do dispatch(:join_us_page) end

  route :get, :post, '/download'                    do dispatch(:download_page) end
  route :get, :post, '/download1'                   do dispatch(:download1_page) end
  route :get, :post, '/download_pc'                 do dispatch(:download_pc_page) end
  route :get, :post, '/dload'                       do dispatch(:dload_page) end

  route :get, :post, '/sitemap/silian_sound.txt'    do dispatch(:silian_sound) end
  route :get, :post, '/sitemap/silian_album.txt'    do dispatch(:silian_album) end
  route :get, :post, '/sitemap/silian_u.txt'        do dispatch(:silian_user) end

end
