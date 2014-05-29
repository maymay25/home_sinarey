
module ApplicationHelper

  def get_profile_user_basic_info(uid)
    this_uid = uid.to_i

    return nil if this_uid < 1
    user = $profile_client.queryUserBasicInfo(this_uid)
    return nil if user.nil? or user.uid.zero?
    user
  end

  def simple_format(string)
    return '' if string.empty?
    string = string.gsub("\n\r","<br />").gsub("\r", "").gsub("\n", "<br />")
    Sanitize.clean(string, :elements => ['a','br','img'], :attributes => {'a' => ['href','target'], 'img' => ['src','alt']})
  end

  def calculate_default_status(user)
    if Settings.is_approve_first
      (user.isVerified || user.isRobot) ? 1 : 0
    else
      1
    end
  end

  def calculate_dig_status(user)
    (user.isVerified || user.isRobot) ? 1 : 0
  end

  def cut_str(str,byte,add=nil)
    l = 0
    ret = ''
    str.each_char do |c|
      l += c.ord > 255 ? 2 : 1
      if l > byte
        ret << add if add
        break
      else
        ret << c
      end
    end
    ret
  end

  def cut_str2(str, byte)
    l = 0
    ret = ''
    str.each_char do |c|
      l += c.ord > 255 ? 2 : 1.2
      if l > byte
        break
      else
        ret << c
      end
    end
    ret
  end

  def cut_groups(groups)
    if groups.size > 0
      groups_str = groups.shift
      groups.each do |g|
        if (g + groups_str).size > 7
          groups_str << '...'
          break
        else
          groups_str << ',' << g
        end
      end
    else
      groups_str = '未分组'
    end
    
    groups_str
  end

  # 输出url、表情、圈某某
  def puts_face(str)
    return '' unless str
    clean_html(parse_names(parse_faces(parse_urls(CGI::escapeHTML(str)))))
  end

  # 输出url
  def parse_urls(str)
    i = str.index(/(http:\/\/|www.)[:\w\.\/\?=&]+/)
    while i
      # 取右近 i 的截断字符为 j
      j = str.index(/[^:\w\.\/\?=&]/, i + 1)
      if j
        html = htmlize_url(str[i...j])
        str[i...j] = html
        i = str.index(/(http:\/\/|www.)[:\w\.\/=&]+/, i + html.size)
      else
        str[i..-1] = htmlize_url(str[i..-1])
        break
      end
    end

    str
  end

  def htmlize_url(url)
    "<a href=\"#{/^http:\/\// =~ url ? url : 'http://' + url}\" rel=\"nofollow\" class=\"a_4\" target=\"_blank\">#{url}</a>"
  end

  # 输出表情
  def parse_faces(str)
    i = str.index('[')
    while i
      # 取右近 i 的闭方括为 j
      j = str.index(']', i + 1)
      if j
        # 取右近 i 的开方括为 k
        k = str.index('[', i + 1)
        if k and k < j
          # k到j
          word = str[(k + 1)...j]
          html = htmlize_face(word)
          str[k..j] = html
          i = str.index('[', k + html.size)
        else
          # i到j
          word = str[(i + 1)...j]
          html = htmlize_face(word)
          str[i..j] = html
          i = str.index('[', i + html.size)
        end
      else
        break
      end
    end

    str
  end

  def htmlize_face(word)
    if FACE_DICT.include?(word)
      "<img src=\"#{File.join(Settings.static_root, FACE_DICT[word])}\" alt=\"#{word}\" title=\"#{word}\" />"
    else
      word
    end
  end

  # 提取被圈名字
  def parse_names(str)
    i = str.index(/@[\w\u4e00-\u9fa5]+/)
    while i
      i += 1
      # 取右近 i 的截断字符为 j
      j = str.index(/[^\w\u4e00-\u9fa5]/, i + 1)
      if j
        name = str[i...j]
        html = htmlize_name(name)
        str[i...j] = html
        i = str.index(/@[\w\u4e00-\u9fa5]+/, html.size + 1)
      else
        name = str[i..-1]
        str[i..-1] = htmlize_name(name)
        break
      end
    end

    str
  end

  def oj_dump(hash)
    Oj.dump(hash, mode: :compat)
  end

  def oj_load(json)
    Oj.load(json)
  end

  def htmlize_name(name)
    his_home = @current_uid ? "/#/n/#{name}/" : "/n/#{name}/"
    "<a href=\"#{his_home}\" class=\"a_4\" rel=\"nofollow\" card=\"n#{name}\">#{name}</a>"
  end
  
  def print_message(label_sym, extra=nil)
    message = Settings.msg[label_sym.id2name]
    return nil unless message
    extra ? message.gsub('{}', ": #{extra}") : message.gsub('{}', '')
  end

  def decode_json_string(str)
    return nil if str.nil? or str.empty?
    begin
      oj_load(str)
    rescue MultiJson::DecodeError
      nil
    end
  end

  def set_my_counts
    if @current_uid
      # 声音数 专辑数 关注数 粉丝数
      @my_tracks_count = TrackRecord.stn(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1).count
      @my_albums_count = Album.stn(@current_uid).where(uid: @current_uid, is_deleted: false, status: 1).count
      @followings_count, @followers_count = $counter_client.getByNames([
          Settings.counter.user.followings,
          Settings.counter.user.followers
        ], @current_uid)
    end
  end

  def set_his_counts(uid)
    # 他的声音数 专辑数 关注数 粉丝数 收藏数
    @his_tracks_count, @his_albums_count, @his_followings_count, @his_followers_count, @his_favorites_count = $counter_client.getByNames([
        Settings.counter.user.tracks, 
        Settings.counter.user.albums,
        Settings.counter.user.followings,
        Settings.counter.user.followers,
        Settings.counter.user.favorites
      ], uid)
  end

  def set_hot_users_and_hot_tags
    # 热门播主
    # human: 2a 4b, cpu: 1c 2d 3e 4f 5g => 1c 2a 3d 4b 5e
    @ranking_users = []

    HumanRecommendCategoryUser.where('category_id = 0').order('position').limit(Settings.per_page.right_recommend_users).each do |h|
      tracks_count = $counter_client.get(Settings.counter.user.tracks, h.uid.to_s) 
      followers_count = $counter_client.get(Settings.counter.user.followers, h.uid.to_s) 
      @ranking_users << [h.uid, h.nickname, h.avatar_path, tracks_count, followers_count, h.personal_signature]
    end
  end

  #他人页面右侧数据
  def set_his_right_info(config)
    return unless config
    uid = config[:uid]

    if config[:followers]
      all_followers = Follower.stn(uid).where(following_uid: uid).select('id, uid, created_at')
      @his_right_followers_count = all_followers.count
      @his_right_followers = all_followers.order('created_at desc').limit(6)
      follower_uids = @his_right_followers.collect{|f| f.uid}
      if follower_uids.size > 0
        @his_right_followers_profile = $profile_client.getMultiUserBasicInfos(follower_uids)
      else
        @his_right_followers_profile = {}
      end
    end

    if config[:followings]
      all_followings = Following.stn(uid).where(uid: uid).select('id, following_uid, created_at')
      @his_right_followings_count = all_followings.count
      @his_right_followings = all_followings.order('created_at desc').limit(6)
      follower_uids = @his_right_followings.collect{|f| f.following_uid}
      if follower_uids.size > 0
        @his_right_followings_profile = $profile_client.getMultiUserBasicInfos(follower_uids)
      else
        @his_right_followings_profile = {}
      end
    end

    if config[:hot_tracks]
      @his_right_hot_tracks = []
    end

    if config[:hot_albums]
      all_album = Album.stn(uid).where(uid: uid) || []
      album_ids = all_album.collect{|a| a.id}
      if album_ids.size > 0
        album_play_counts = $counter_client.getByIds(Settings.counter.album.plays, album_ids)
        album_merge_arr = album_ids.each_with_index.collect { |a,index| [album_play_counts[index],all_album[index]] }
        @his_right_hot_albums = album_merge_arr.sort_by{|a|a[0]}.reverse[0,8].collect{|a|a[1]}
      else
        @his_right_hot_albums = []
      end
    end
    
    if config[:common_like] & @current_uid
      begin
        _sql = "SELECT * FROM " << Favorite.stn(@current_uid).table_name << " f1 INNER JOIN " << Favorite.stn(config[:uid]).table_name << " f2 ON f1.track_id = f2.track_id WHERE f1.uid= #{@current_uid} AND f2.uid=" << config[:uid] << " order by f2.created_at desc"
        @his_common_like = Favorite.find_by_sql(_sql)
      rescue
        @his_common_like = nil
      end
    end
    
  end

  # 推荐服务 个人电台
  def set_recommend_right_info
    @recommend_right_hot_users = get_recommend_user(nil,1,6)[:list][0,4]
    @recommend_right_new_users = get_recommend_new_user(nil,1,6)[:list][0,4]
    @recommend_right_followed_users = get_recommend_followed_user(nil,1,6)[:list][0,4]
  end

  

  def parse_date(datestr)
    datestr.to_datetime.strftime('%-m月%-d日 %H:%M')
  end

  def link_path(path)
    (@current_uid and @current_uid > 0) ? ('/#' << path) : path
  end

  def link_his_path(his_uid, tail=nil)
    path = case tail
    when 'follow'
      "/#{his_uid}/follow/"
    when 'fans'
      "/#{his_uid}/fans/"
    when 'sound'
      "/#{his_uid}/sound/"
    else
      "/#{his_uid}/"
    end
    
    link_path(path)
  end

  def login_url
    "#{Settings.login_url}?fromUri=#{request.protocol + request.host_with_port}"
  end

  def parse_time_until_now(time)
    time = time.to_datetime if time.is_a?(String)
    fsec = Time.new - time
    fmin = fsec / 60
    fhour = fmin / 60
    fday = fhour / 24
    fmon = fday / 30
    fyear = fmon / 12

    sec = fsec.to_i
    min = fmin.to_i
    hour = fhour.to_i
    day = fday.to_i
    mon = fmon.to_i
    year = fyear.to_i

    year > 0 ? "#{year}年前" : (mon > 0 ? "#{mon}月前" : (day > 0 ? "#{day}天前" : (hour > 0 ? "#{hour}小时前" : (min > 5 ? "#{min}分钟前" : "刚刚"))))
  end

  def parse_wan(num)
    if num >= 10000
      "#{num / 10000}.#{(num % 10000)/1000}万"
    else
      num.to_s
    end
  end

  # meta信息 动态替换
  def parse_seo_meta(type,data,str)

    if type=="tag" #标签页
      str.gsub!("$tname",(data[:tname] || ""))
      str.gsub!("$intro",(data[:intro] || ""))
    elsif type=="album" #专辑页
      str.gsub!("$album_title",(data[:title] || ""))
      str.gsub!("$category_title",(data[:category_title] || ""))
      str.gsub!("$tags",(data[:tags] || ""))
      str.gsub!("$intro",(data[:intro] || ""))
    elsif type=="track" or type=="tracklikers" #声音页
      str.gsub!("$title",(data[:title] || ""))
      str.gsub!("$album_title",(data[:album_title] || ""))
      str.gsub!("$category_title",(data[:category_title] || ""))
      str.gsub!("$author",(data[:author] || ""))
      str.gsub!("$nickname",(data[:nickname] || ""))
      str.gsub!("$tags",(data[:tags] || ""))
      str.gsub!("$intro",(data[:intro] || ""))
      str.gsub!("$composer",(data[:composer] || ""))
      str.gsub!("$announcer",(data[:announcer] || ""))
      
      source_filter = {1=>"原创",2=>"翻唱"}
      str.gsub!("$source",(source_filter[data[:user_source]] || ""))
    elsif type=="user" #个人页
      str.gsub!("$nickname",(data.nickname || ""))
      str.gsub!("$personal_signature",(data.personalSignature || ""))
    elsif type=="page"  #分类页
      str.gsub!("$category_title",data[:category_title]) if data[:category_title]
    end

    if params and params[:page] and params[:page]!=""
      str.gsub!("$page","第#{params[:page]}页")
    else
      str.gsub!("$page","")
    end

    str
  end

  private

  def set_assets_version
    @assets_version = assets_version
  end
  
  def parse_root_domain
    host = request.host
    if host 
      m = host.match("[^.]*\\.(com|cn|net|org|biz|info|cc|tv){1,2}")
      if m && m.size > 1
        root_domain = m[0]
        return '.' + root_domain
      end
    end

    nil
  end

  def get_badge(uid)
    $counter_client.getByNames([
      Settings.counter.user.new_message,
      Settings.counter.user.new_notice,
      Settings.counter.user.new_comment,
      Settings.counter.user.new_quan,
      Settings.counter.user.new_follower,
      ], uid
    ).reduce(:+)
  end

  def get_upload_source(source)
    res = '未知'
    case source
    when 1
      res = '苹果'
    when 2
      res = '电脑'
    when 3
      res = '安卓'
    when 4
      res = '桌面版'
    end

    res
  end

  def javascript_data_options(json)
    return nil unless json.is_a?(Hash)
    json = json.delete_if {|key, value| value.nil? }
    arr = []
    json.each do |key,value|
      arr << "#{key}:#{value}"
    end

    arr.join(",")
  end

  #获取指定用户的关注状态
  def check_follow_status(uid)
    if @current_uid and uid and @current_uid!=uid
        following = Following.stn(@current_uid).where(uid: @current_uid, following_uid: uid).select('following_uid, is_mutual').first
        @is_follow = following.present? 
        @be_followed = following && following.is_mutual
    else
        @is_follow = false
        @be_followed = false
    end
  end

  #客户端ip
  def get_client_ip
    @temp[:client_ip] ||= env['X-REAL-IP'] || request.ip
  end



  def params_page
    @temp[:params_page] ||= begin
      if params[:page].present?
        params[:page].to_i
      else
        1
      end
    end
  end

  #设置分页的默认值
  def paginate(sequel_pagination = nil, options = {})
    options[:previous_label] ||= '上一页'
    options[:next_label] ||= '下一页'
    options[:inner_window] ||= 3
    options[:outer_window] ||= 0
    options[:class] = 'pagingBar_wrapper'
    options[:params] = params if request.post?
    
    temp = PaginateTemp.new(sequel_pagination)
    will_paginate(temp, options)
  end

end