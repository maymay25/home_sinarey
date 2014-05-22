class XposterRoute < XposterController

  route :get,        '/xposter/dub'                do dispatch(:dub_homepage) end
  route :get,        '/xposter/dub_dub'            do dispatch(:dub_dub) end
  route :get,        '/xposter/dub_translate'      do dispatch(:dub_translate) end
  route :get,        '/xposter/dub_works'          do dispatch(:dub_works) end

  route :get,        '/xposter/starsport'          do dispatch(:starsport_homepage) end
  route :get,        '/xposter/starsport_help'     do dispatch(:starsport_help) end
  route :get,        '/xposter/starsport_works'    do dispatch(:starsport_works2) end

end