module CenterHelper


  def get_timeline_meta(uid,jointime=nil)

    return nil if uid.nil? or uid==0

    current_year = Time.now.year
    current_month = Time.now.month

    init_year = (params[:year] && params[:year].to_i) || current_year

    init_month = init_year == current_year ? current_month : 12
    init_month = params[:month].to_i if params[:month]

    response = {init:{year:init_year,month:init_month},list:[]}
    #参数为uid 返回发过feed的时间列表
    
    metainfo = $feed_client.getTimelineMetaInfo(uid)
    return nil if metainfo.nil?
    #calendars << jointime if jointime and !calendars.include? jointime
    metainfo = metainfo.sort.reverse

    generated_calendar = {}
    metainfo.each do |date|
        year , month = date[0..-3].to_i , date[-2..-1].to_i
        generated_calendar[year] = [] unless generated_calendar[year]
        generated_calendar[year] << month
    end

    generated_calendar.each do |year,months|
        nick_year = (year == current_year) ? "现在" : year
        response[:list] << {year:year, month:generated_calendar[year][0], nick_year:nick_year,months_list:generated_calendar[year].sort.reverse}
    end
    if jointime
        response[:list] << {year:jointime.year-10, month:jointime.month, nick_year:'加入',months_list:[jointime.month]}
    end
    
    return response
  end

  def init_timeline_data
    uid = params[:uid] && params[:uid].to_i
    return nil if uid.nil? or uid==0

    page = (params[:page] && params[:page].to_i) || 1
    per_page = (params[:per_page] && params[:per_page].to_i) || 10

    if params[:year] and params[:month]
      time = Time.new(params[:year],params[:month],nil)
      strftime = time.strftime("%Y%m")
      #参数分别为 时间,uid,page,pagesize #返回feed的信息
      timeline_result = $feed_client.getTimelineData(strftime,uid,page,per_page,nil)
    else
      timeline_result = nil
    end
    return timeline_result
  end


  def get_timeline_barlist

    current_year = Time.now.year
    current_month = Time.now.month
    # TODOREVIEW: 传值更好
    init_year = (params[:year] && params[:year].to_i) || current_year

    init_month = init_year == current_year ? current_month : 12
    init_month = params[:month].to_i if params[:month]

    response = {init:{year:init_year,month:init_month},list:[]}

    response[:list] << {year:current_year, month:current_month, nick_year:'现在',months_list:(1..current_month).to_a.reverse} if current_month > 1

    all_month = (1..12).to_a.reverse
    9.times do |y|
        year = current_year-1-y
        response[:list] << {year:year, month:all_month[0], nick_year:year,months_list:all_month}
    end

    return response
  end

  def word(min,max)
      k = ("a".."z").to_a
      word = ""
      w_length = (min..max).to_a.sample
      w_length.times do |a|
        word += k.sample 
      end
      return word
  end

  def sentence(w_min,w_max,s_min,s_max)
    sentence = ""
    s_length = (s_min..s_max).to_a.sample
    s_length.times do |t|
      sentence += word(w_min,w_max)
      sentence += " "
    end
    return sentence
  end


end
