class XposterController < ApplicationController

  set :views, ['xposter','application']

  def dispatch(action)
    super(:xposter,action)
    method(action).call
  end

  #译声一试
  def dub_homepage
  	erb :dub_homepage,layout:false
  end

  def dub_dub
    erb :dub_dub,layout:false
  end

  def dub_translate
    erb :dub_translate,layout:false
  end

  def dub_works

    uid = Sinarey.env=='development' ? 18 : 8227231

    cond1 = {uid: uid, status: 1, is_deleted: false, is_public:true}
    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = 12

    if params[:sort]=='new'
      all_tirs = TrackRecord.stn(uid).where(cond1)
      @all_tirs_count = all_tirs.count
      @tirs = all_tirs.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
      hit_ids = @tirs.map{|tir| tir.track_id }
      @favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)
    else
      all_tirs = TrackRecord.stn(uid).where(cond1).all.to_a
      @all_tirs_count = all_tirs.length

      hit_ids = all_tirs.map{|tir| tir.track_id }

      favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)

      data = all_tirs.zip(favorites_counts).sort{|d1,d2| d2[1] <=> d1[1] }

      offset = (@page-1)*@per_page
      page_data = data[offset,@per_page]

      @tirs = []
      @favorites_counts = []

      page_data.each do |data|
        @tirs << data[0]
        @favorites_counts << data[1]
      end
    end

    if @tirs.length > 0

      track_ids = @tirs.collect{|r| r.track_id }

      @plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)

      @is_favorited = {}
      if @current_uid
        favorite_status = Favorite.stn(@current_uid).where(uid: @current_uid, track_id: track_ids)
        favorite_status.each do |f|
          @is_favorited[f.track_id] = 1
        end
      end

      track_uids = @tirs.collect{|r| r.track_uid }
      profile_users = $profile_client.getMultiUserBasicInfos(track_uids)
      @user_list = []
      track_uids.each_with_index do |uid,i|
        if u = profile_users[uid]
          @user_list << u
        end
      end
    end

    erb :dub_works,layout:false
  end

  def starsport_homepage
    erb :starsport_homepage,layout:false
  end

  def starsport_help
    erb :starsport_help,layout:false
  end

  def starsport_works

  	uid = Sinarey.env=='development' ? 18 : 9485923

    cond1 = {uid: uid, status: 1, is_deleted: false, is_public:true}
    @page = ( tmp=params[:page].to_i )>0 ? tmp : 1
    @per_page = 12

    if params[:sort]=='new'
      all_tirs = TrackRecord.stn(uid).where(cond1)
      @all_tirs_count = all_tirs.count
      @tirs = all_tirs.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
      hit_ids = @tirs.map{|tir| tir.track_id }
      @favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)
    else
      all_tirs = TrackRecord.stn(uid).where(cond1).all.to_a
      @all_tirs_count = all_tirs.length

      hit_ids = all_tirs.map{|tir| tir.track_id }

      favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)

      data = all_tirs.zip(favorites_counts).sort{|d1,d2| d2[1] <=> d1[1] }

      offset = (@page-1)*@per_page
      page_data = data[offset,@per_page]

      @tirs = []
      @favorites_counts = []

      page_data.each do |data|
        @tirs << data[0]
        @favorites_counts << data[1]
      end
    end

    if @tirs.length > 0

      track_ids = @tirs.collect{|r| r.track_id }

      @plays_counts = $counter_client.getByIds(Settings.counter.track.plays, track_ids)

      @is_favorited = {}
      if @current_uid
        favorite_status = Favorite.stn(@current_uid).where(uid: @current_uid, track_id: track_ids)
        favorite_status.each do |f|
          @is_favorited[f.track_id] = 1
        end
      end

      track_uids = @tirs.collect{|r| r.track_uid }
      profile_users = $profile_client.getMultiUserBasicInfos(track_uids)
      @user_list = []
      track_uids.each_with_index do |uid,i|
        if u = profile_users[uid]
          @user_list << u
        end
      end
    end

    erb :starsport_works,layout:false
  end

end