class TagsController < ApplicationController
  include SearchHelper

  set :views, ['tags','application']

  def dispatch(action,params_options={})
    params_options.each {|k,v| params[k] = v }
    super(:tags,action)
    method(action).call
  end

  def show_page

    redirect_to_root

    set_no_cache_header

    @tag_name = params[:tname].to_s
    halt_404 if !TAG_SERVICE.exist(@tag_name)
      
    halt_404 if %w[ 卢台长 卢军宏 玄艺综述 玄艺问答 直话直说 白话佛法 ].include?(@tag_name)

    tag_followers = FollowerTag.shard(@tag_name).where(tname: @tag_name).order("created_at desc")
    @is_follow = tag_followers.where(uid: @current_uid).any?
    @tags_followers_count = tag_followers.count

    @categories = {}.tap{ |h| Category.order("order_num asc").each{ |c| h[c.id] = [c.name, c.title] } }
    scope_list = ["hot","v_hot","recent","v_recent"]
    @scope = scope_list.include?(params[:scope]) ? params[:scope] : "hot"
    
    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = Settings.per_page.tag_tracks || 10
    @fq = "is_v:true" if @scope == "v_hot" || @scope == "v_recent"
    @sort = (@scope=="recent" || @scope=="v_recent") ? "created_at+desc" : "tag_play+desc"
    start = (@page-1)*@per_page
    solr_data = solr_tag_tracks(@tag_name,query={:fq => @fq, :wt => "json", :sort => @sort, :start => start, :rows => @per_page})

    @tagtracks = solr_data["response"]["docs"]
    track_ids = @tagtracks.collect{|t| t['trackid']}
    if track_ids.size > 0
      @plays_count = $counter_client.getByIds(Settings.counter.track.plays, track_ids)
      @comments_count = $counter_client.getByIds(Settings.counter.track.comments, track_ids)
      @shares_count = $counter_client.getByIds(Settings.counter.track.shares, track_ids)
      @favorites_count = $counter_client.getByIds(Settings.counter.track.favorites, track_ids)
    else
      @plays_count = []
      @comments_count = []
      @shares_count = []
      @favorites_count = []
    end
    @tagtracks.each_with_index do |t, i|
      t['count_play'] = @plays_count[i]
      t['count_comment'] = @comments_count[i]
      t['count_share'] = @shares_count[i]
      t['count_like'] = @favorites_count[i]
      t['category_name'] = @categories[t["category_id"].to_i]
    end

    @tagtracks_count = solr_data["response"]["numFound"] || 0

    @this_title = "#{@tag_name} 喜马拉雅-听我想听"

    halt erb_js(:show_js) if request.xhr?
    erb :show
  end

  #标签详情页右侧
  def show_right

    halt_404 unless request.xhr?

    set_no_cache_header

    @tag_name = params[:tname].to_s
    halt if !TAG_SERVICE.exist(@tag_name)

    halt render_to_string(partial: :_show_right)
  end

  #感兴趣的人
  def follower_page

    set_no_cache_header

    @tag_name = params[:tname].to_s

    halt_404 if !TAG_SERVICE.exist(@tag_name)

    tag_followers = FollowerTag.shard(@tag_name).where(tname: @tag_name).order("created_at desc")
    @is_follow = tag_followers.where(uid: @current_uid).any?
    @tags_followers_count = tag_followers.count
    @categories = {}.tap{ |h| Category.order("order_num asc").each{ |c| h[c.id] = c.title } }
    @scope = params[:scope].nil? ? "hot" : ( scope_list.index(params[:scope]).nil? ? "hot" : params[:scope] )
    @fq = "is_v:true" if @scope == "v_hot" || @scope == "v_recent"
    @sort = (@scope=="recent" || @scope=="v_recent") ? "created_at+desc" : "tag_play+desc"
    solr_data = solr_tag_tracks(@tag_name,query={:fq => @fq, :wt => "json", :sort => @sort, :start => 1, :rows => 1})
    @tagtracks_count = solr_data["response"]["numFound"]

    #follower列表
    @per_page = 10
    @page = params["page"].nil? ? 1 : params["page"].to_i
    @follow_status = {}
    
    @tagfollowers_count = tag_followers.count
    follower_uids = tag_followers[(@page-1)*@per_page,@per_page].collect{|t| t.uid}
    if follower_uids.size > 0
      profile_users = $profile_client.getMultiUserBasicInfos(follower_uids)
      @tagfollowers = follower_uids.collect{ |uid| profile_users[uid] }
      @user_tracks_counts = $counter_client.getByIds(Settings.counter.user.tracks, follower_uids)
      @user_followers_counts = $counter_client.getByIds(Settings.counter.user.followers, follower_uids)
      @user_followings_counts = $counter_client.getByIds(Settings.counter.user.followings, follower_uids)
      if @current_uid
        followings = Following.shard(@current_uid).where(uid: @current_uid, following_uid: follower_uids).select('following_uid, is_mutual')
        followings.each do |follow|
          @follow_status[follow.following_uid] = [true,follow.is_mutual]
        end
      end
    end
    
    @this_title = "#{@tag_name} 喜马拉雅-听我想听"

    halt erb_js(:follower_js) if request.xhr?
    erb :follower
  end

  # 感兴趣和不感兴趣
  def switch_follow

    halt_404 if @current_uid.nil?

    @tag_name = params[:tname].to_s.strip
    halt render_json({response:'nothing'}) if @tag_name.blank?

    ftag = FollowingTag.shard(@current_uid).where(uid: @current_uid, tname: @tag_name).first
    if ftag

      ftag.destroy

      $counter_client.decr(Settings.counter.user.following_tags, ftag.uid, 1)

      $counter_client.decr(Settings.counter.tag.users, ftag.tname, 1)

      response = "destroy"
    else
      if TAG_SERVICE.exist(@tag_name)

        ftag = FollowingTag.create(uid: @current_uid, tname: @tag_name)

        $counter_client.incr(Settings.counter.user.following_tags, ftag.uid, 1)

        $counter_client.incr(Settings.counter.tag.users, ftag.tname, 1)

        response = "create"
      else
        response = "nothing"
      end
    end
    halt render_json({response:response})
  end

end