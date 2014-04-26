MUSIC_CATEGORIES = ["原唱","翻唱","伴奏","小样","K歌","音效","音乐节目"]

CATEGORIES = {}.tap do |h|
  Category.all.map do |category|
    h[category.id] = [ category.name, category.title ]
  end
end
