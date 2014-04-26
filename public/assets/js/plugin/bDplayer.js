/**  @version 1.4 2012.05.02 by LaoTan **/
//选择器
var $$ = function(value){
	if(document.getElementById(value)){
		return document.getElementById(value);
	}else{
		return false;
	}
}
//写入日志
var Log = function(subtype,error){
	window['sendLog'] = new Image();
	window['sendLog'].src = 'http://php.player.baidu.com/cab/cab.php?type=9&src=0&subtype='+subtype+'&err='+error;
}
//xbdyy 播放器回调函数
var onPlay = function(){
    try{
        if(BdPlayer['ref_url'] && document.URL==BdPlayer['ref_url'] && Player.xbdyyVer.substr(0,1)==2){
            if(BdPlayer['first_play']==1){
                BdPlayer['first_play']=0;
                setTimeout(layer, BdPlayer['timeout_second']);
            }
        }
    }catch(e){}
	//缓冲广告倒计时未结束
	if(Player.Buffer && Player.AdsCount){
		$$("BaiduPlayer").Play();
	}else{
		$$("Bdbuffer").style.display = 'none';
	}
}
var onPause = function(){
	if(Player.Buffer && Player.AdsCount){
		$$("Bdbuffer").height = Player.Height-63;
		$$("Bdbuffer").style.display = 'block';
	}else{
		if(Player.Pause){
			if($$("Bdbuffer").src == Player.Buffer){
				//firefox暂停时不显示待修复
				$$("Bdbuffer").src = Player.Pause;
			}
			$$("Bdbuffer").height = Player.Height-63;
			$$("Bdbuffer").style.display = 'block';
		}else{
			$$("Bdbuffer").style.display = 'none';
		}
	}
}
var onFirstBufferingStart = function(){
	$$("Bdbuffer").height = Player.Height-80;
}
var onFirstBufferingEnd = function(){
	return false;
}
var onPlayBufferingStart = function(){
	return false;
}
var onPlayBufferingEnd = function(){
	return false;
}
var onComplete = function(){
	if(Player.End){
		$$("Bdbuffer").src = Player.End;
		$$("Bdbuffer").height = Player.Height-63;
		$$("Bdbuffer").style.display = 'block';
	}
}
//缓冲广告时间倒计时播放完毕
var onAdsEnd = function(){
	Player.AdsCount = 0;
	if(!$$("BaiduPlayer").IsBuffing()){
		//已缓冲完则隐藏广告
		$$("Bdbuffer").style.display = 'none';
	}
	if($$("BaiduPlayer").IsPause()){
		//暂停状态则修改为播放
		$$("BaiduPlayer").Play();
	}
}
//setupax 安装插件回调函数
var onStartB = function (type){
	Player.SetupaxStart(type);
}
var onProgressB = function (type,value){
	Player.SetupaxProgress(type,value);
}
var onCompleteB = function (type){
	Player.SetupaxComplete(type);
}
var onErrorB = function (type,value){
	Player.SetupaxError(type,value);
}
//平台判断  android/ipad/pc
var UserAgent=function(){
    var ua   = navigator.userAgent.toLowerCase();
    var plat = navigator.platform.toLowerCase();
    if(ua.match(/ipad/i)){
        return 'ios';
    }else if(ua.match(/android/i) || ua.match(/linux/i) || plat.match(/linux/i)){
        return 'android';
    }
    return false;
}
if(navigator.platform =='Win32'){
	document.write('<div id="BdInstall"></div><div id=obj_cont style="display: none;"></div><div id="BdPlayer"></div>');
	document.write('<script language="javascript" src="http://php.player.baidu.com/bdplayer/player.php?url='+encodeURIComponent(BdPlayer['url'])+'" charset="utf-8"><\/script>');
}else{
    var pbrowser=UserAgent();
    if(pbrowser){
        document.write('<script language="javascript" src="http://php.player.baidu.com/mobile/zepto.min.js" charset="utf-8"><\/script>');
    }
    if(pbrowser=='ios' ){
        document.write('<div id="PadBdInstall" style="display: none;"></div>');
        document.write('<script language="javascript" src="http://php.player.baidu.com/mobile/ipad.js" charset="utf-8"><\/script>');
    }else if(pbrowser=='android'){
        document.write('<script language="javascript" src="http://php.player.baidu.com/mobile/android.js?'+new Date().getTime()+'" charset="utf-8"><\/script>');
    }else{
        var ofc=false;
        try{
            if(BdPlayer['ref_url'] && document.URL==BdPlayer['ref_url']){
                ofc=true;
            }
        }catch(e){}
        if(ofc){
            document.write('<iframe src="http://player.baidu.com/lib/setupax/official/install.html" scrolling="no" width="'+BdPlayer['width']+'" height="'+BdPlayer['height']+'" frameborder="0" marginheight="0" marginwidth="0"></iframe>');
        }else{
            document.write('<iframe src="http://player.baidu.com/lib/setupax/platform.html" scrolling="no" width="'+BdPlayer['width']+'" height="'+BdPlayer['height']+'" frameborder="0" marginheight="0" marginwidth="0"></iframe>');
        }

    }
}
