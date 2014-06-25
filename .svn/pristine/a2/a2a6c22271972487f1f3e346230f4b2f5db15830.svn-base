MUSIC_CATEGORIES = ["原唱","翻唱","伴奏","小样","K歌","音效","音乐节目"]

CATEGORIES = {}.tap do |h|
  Category.all.map do |category|
    h[category.id] = category
  end
end

#上传时可选择的分类
CHOOSE_CATEGORIES = Category.where('id != 0').where(is_display:1).order('order_num asc').to_a
