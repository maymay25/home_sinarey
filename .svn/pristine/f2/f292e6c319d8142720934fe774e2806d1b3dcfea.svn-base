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
      all_tirs = TrackRecord.shard(uid).where(cond1)
      @all_tirs_count = all_tirs.count
      @tirs = all_tirs.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
      hit_ids = @tirs.map{|tir| tir.track_id }
      @favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)
    else
      all_tirs = TrackRecord.shard(uid).where(cond1).all.to_a
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
        favorite_status = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids)
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
      all_tirs = TrackRecord.shard(uid).where(cond1)
      @all_tirs_count = all_tirs.count
      @tirs = all_tirs.order('id desc').offset((@page-1)*@per_page).limit(@per_page)
      hit_ids = @tirs.map{|tir| tir.track_id }
      @favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)
    else
      all_tirs = TrackRecord.shard(uid).where(cond1).all.to_a
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
        favorite_status = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: track_ids)
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

  #20强名单
  def starsport_works2
    if Sinarey.env=='development'
      track_ids = [214682, 214622, 214609, 214608, 214531, 214526, 214523, 214522, 214521, 214508, 214507, 214506, 214505, 214485, 214265, 214264, 214263, 214262, 214261, 214045]
      track_ids2 = [214611]
    else
      track_ids = [2674464,2666960,2674859,2669520,2661227,2667778,2647840,2686697,2680616,2701147,2716280,2722176,2731895,2731987,2732362,2733062,2735296,2737795,2689621,2704667]
      track_ids2 = [2651996]
    end

    @tracks = Track.mfetch(track_ids,true)
    hit_ids = @tracks.map{|track| track.id }
    hit_uids = @tracks.map{|track| track.uid }
    if hit_ids.length > 0
      @favorites_counts = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids)
      @plays_counts = $counter_client.getByIds(Settings.counter.track.plays, hit_ids)
    end

    @tracks2 = Track.mfetch(track_ids2,true)
    hit_ids2 = @tracks2.map{|track| track.id }
    hit_uids2 = @tracks2.map{|track| track.uid }
    if hit_ids2.length > 0
      @favorites_counts2 = $counter_client.getByIds(Settings.counter.track.favorites, hit_ids2)
      @plays_counts2 = $counter_client.getByIds(Settings.counter.track.plays, hit_ids2)
    end

    @is_favorited = {}
    all_hit_ids = (hit_ids + hit_ids2).uniq
    if all_hit_ids.length >0
      if @current_uid
        favorite_status2 = Favorite.shard(@current_uid).where(uid: @current_uid, track_id: all_hit_ids)
        favorite_status2.each do |f|
          @is_favorited[f.track_id] = 1
        end
      end
    end

    @profile_users = {}
    all_hit_uids = (hit_uids + hit_uids2).uniq
    if all_hit_uids.length>0
      @profile_users = $profile_client.getMultiUserBasicInfos(all_hit_uids)
    end

    erb :starsport_works2,layout:false
  end

end