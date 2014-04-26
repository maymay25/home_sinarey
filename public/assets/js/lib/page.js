define([
		'jquery',
		'underscore'
], function( $, _ ){

		var isIE6 = $('body').attr('id')=='ie6';

		var Page = {
				isIE6:isIE6,
				showIconDynamic:function(ele,icon,on){
						if(isIE6){
								return
						}
						require(['text!templates/iconDynamic.html'], function( iconDynamicTemplate ){
								var $this = $(ele),
										empty_tpl = _.template( iconDynamicTemplate );
								var div = empty_tpl({
										icon:icon,
										on:on
								});
								var pos = ele.offset(),
										$div = $(div);
								$div.css({
									left: pos.left,
									top: pos.top-6
								});
								$(document.body).append($div);
								$div.stop().animate({
									top: pos.top - 25,
									opacity: 'toggle'
								}, 1500, function () {
									$div.remove();
								});
						})
				},
				shine:function(c){
					var b = function(a) {
							return a.slice(0, a.length - 1).concat(a.concat([]).reverse())
					};
					var e = {start: "#fff",color: "#fbb",times: 2,step: 5,length: 4},
							f = e.start.split(""),
							g = e.color.split(""),
							h = [];
					for (var i = 0; i < e.step; i += 1) {
						var j = f[0];
						for (var k = 1; k < e.length; k += 1) {
							var l = parseInt(f[k], 16),
							m = parseInt(g[k], 16);
							j += Math.floor(parseInt(l + (m - l) * i / e.step, 10)).toString(16);
						}
						h.push(j)
					}
					for (var i = 0; i < e.times; i += 1) h = b(h);
					var n = !1,
					interval = setInterval(function(){
						if (!h.length) clearInterval(interval);
						else {
							if (n) {
								n = !1;
								return
							}
							n = !0;
							c.css('background-color',h.pop());
						}
					},25)
				},
				create_box:function(box,ele,time){
						var $box = $(box);
						var box_outer_width = $box.outerWidth(),
								box_outer_height = $box.outerHeight(),
								box_height = $box.height();

						if(ele){
								var $ele = $(ele);

								var left = $ele.offset().left-(box_outer_width-$ele.outerWidth())/2;

								var body_width = $('body').width();

								if(left>body_width-box_outer_width){
										left = body_width-box_outer_width;
								}else if(left<0){
										left=0;
								}

								if( time==0 || (time && time>0) ){
										var top = $ele.offset().top-3;
										var pos = {
												top: top,
												left: left
										};

										$box.css('height',0).offset(pos).stop().animate({'height':box_height,top:top-box_outer_height},200,function(){
											 if(time>0){
														$box.animate({'background-color':'white'},time,function(){
																$box.animate({'height':0,top:top},200,function(){$box.stop().remove();});
														})
												}
										});
								}else{
										var pos = {
												top: $ele.offset().top-$box.outerHeight()-3,
												left: left
										};
										$box.offset(pos);
								}
						}else{
								var window_height = $(window).height(),
										window_width = $(window).width();

								var left = (window_width-box_outer_width)/2;
								if($('body').hasClass('iframe')){
										var top=100;
										$box.css('top',''+top+'px').css('left',''+left+'px');
								}else{
										var calc_top=(window_height-box_outer_height)/2;
										if(calc_top>50){
												var top = calc_top - 50;
										}else{
												var top = 0;
										}
										$box.css('position','fixed').css('top',''+top+'px').css('left',''+left+'px');
								}
						}
				},
				remove_box:function(box,beautiful){
						var $box = $(box);
						if($box.length>0){
								if(beautiful){
										var box_top = parseInt($box.css('top'));
												box_outer_height = $box.outerHeight();
										console.info();
										var top = box_top + box_outer_height;
										$box.stop().animate({'height':0,top:top},200,function(){$box.stop().remove();});
								}else{
										$box.stop().remove();
								}
						}
				},
				showTipBox:function(ele,txt,style,time){
						require(['text!templates/tipBox.html'], function( tipBoxTemplate ){
								var $this = $(ele),
										empty_tpl = _.template( tipBoxTemplate );
								$(".alert-tips").stop().remove();
								var box = empty_tpl({
										txt:txt,
										style:style
								});

								$('body').append(box);
								var $box = $("#alert-tips");

								Page.create_box($box,$this,time);

						})
				},
				showConfirmBox:function(ele,txt,callback){
						require(['text!templates/confirmBox.html'], function( confirmBoxTemplate ){
								var $this = $(ele),
										empty_tpl = _.template( confirmBoxTemplate );
								$(".confirmBox").stop().remove();

								var box = empty_tpl({
										txt:txt
								});
								$('body').append(box);
								var $box = $("#confirmBox");
								$box.find('button.commit').bind('click',function(){
										callback();
								})
								Page.create_box($box,$this,0);
						})
				},
				showLoginBox:function(ele,notice,title){
						require(['text!templates/loginBox.html'], function( loginBoxTemplate ){
								var empty_tpl = _.template( loginBoxTemplate );
								$(".loginBox").stop().remove();
								var box = empty_tpl({
										notice:notice,
										title:title
								});
								$('body').append(box);
								var $box = $("#loginBox");

								if(ele){
										var $ele = $(ele);
										Page.create_box($box,$ele,0);
								}else{
										Page.create_box($box,null,null);
								}
						})
				},
				showTopTip:function(txt,style){
						require(['text!templates/topTip.html'], function( topTipTemplate ){
								var empty_tpl = _.template( topTipTemplate );
								$(".topTip").stop().remove();
								var box = empty_tpl({
										txt:txt,
										style:style
								});
								$('body').append(box);
								var $box = $("#topTip");
								var body_width = $('body').width(),
										tip_width = $box.outerWidth(),
										tip_height = $box.outerHeight();
								var left = (body_width-tip_width)/2;

								$box.css('top','-'+tip_height+'px').css('left',''+left+'px');

								$box.stop().animate({'top':'0px'},800,function(){
										$box.animate({'left':''+left+'px'},1200,function(){
												$box.animate({'top':'-'+tip_height+'px'},800,function(){$box.remove()})
										})
								})
						})
				},
				showTopNotice:function(txt,style){
						require(['text!templates/noticeBox.html'], function( noticeBoxTemplate ){
								var empty_tpl = _.template( noticeBoxTemplate );
								$(".noticeBox").stop().remove();
								var box = empty_tpl({
										txt:txt,
										style:style
								});
								$('body').append(box);
								var $box = $("#noticeBox");
								var body_width = $('body').width(),
										tip_width = $box.outerWidth(),
										tip_height = $box.outerHeight();
								var left = (body_width-tip_width)/2;

								$box.css('top','-'+tip_height+'px').css('left',''+left+'px');

								$box.stop().animate({'top':'0px'},800,function(){
										$box.animate({'left':''+left+'px'},2200,function(){
												$box.animate({'top':'-'+tip_height+'px'},800,function(){$box.remove()})
										})
								})
						})
				},
				showCenterNotice:function(txt,style){
						require(['text!templates/noticeBox.html'], function( noticeBoxTemplate ){
								var empty_tpl = _.template( noticeBoxTemplate );
								$(".noticeBox").stop().remove();
								var box = empty_tpl({
										txt:txt,
										style:style
								});
								$('body').append(box);
								var $box = $("#noticeBox");
								Page.create_box($box,null,null);
								setTimeout(function(){
										Page.remove_box($box);
								},2000);
						})
				},
				showQZMsg:function(txt,style){
						require(['text!templates/qzMsgBox.html'], function( noticeBoxTemplate ){
								var empty_tpl = _.template( noticeBoxTemplate );
								$(".qzMsgBox").stop().remove();
								var box = empty_tpl({
										txt:txt,
										style:style
								});
								$('body').append(box);
								var $box = $("#qzMsgBox");
								Page.create_box($box,null,null);
								setTimeout(function(){
										Page.remove_box($box);
								},2000);
						})
				},
				showShareBox:function(shareTo,callback){
						require(['text!templates/shareBox.html'], function( shareBoxTemplate ){
								var empty_tpl = _.template( shareBoxTemplate );
								$(".shareBox").stop().remove();

								var box = empty_tpl({
										shareTo:shareTo
								});
								$('body').append(box);
								var $box=$("#shareBox");
								var commit_btn = $box.find('button.commit');
								commit_btn.bind('click',function(){
										callback($box,this);
								});
								Page.create_box($box,null,0);
						})
				},
				showChatBox:function(params,callback){
						var uid = params.uid,
								nickname = params.nickname;
						if(!uid || !callback){
				      return false;
				    };
						require(['text!templates/chatBox.html'], function( chatBoxTemplate ){
								var empty_tpl = _.template( chatBoxTemplate );
								$(".chatBox").stop().remove();
								var box = empty_tpl({
										uid:uid,
										nickname:nickname
								});
								$('body').append(box);
								var $box=$("#chatBox"),
										commit_btn = $box.find('#chatBox_submit'),
										input = $box.find('#chatBox_content');
										cache_content = window.cache_chatBox_content;
								if(cache_content){
									input.val(cache_content);
								};
								input.focusEnd();
								commit_btn.bind('click',function(){
									var content = input.val();
									if(content&&content.trim()){
										callback(content);
									}else{
										Page.shine(input);
										input.focus();
										return false;
									};
								});
								Page.create_box($box,null,0);
						})
				},
				todo_event:{
						create:function(p){
								if(p && p['dom'] && p['event']){
										window.todo_event = p;
								}
						},
						remove:function(){
								window.todo_event = null;
						},
						active:function(){
								var e = window.todo_event;
								if(e && e['dom'] && e['event']){
										$(e['dom']).trigger(e['event']);
								}
								window.todo_event = null;
						}
				},
				oauth2_window_cache:null,
				oauth2_window:{
						close:function(){
								var win = this.oauth2_window_cache;
								if(win){
										win.close();
										win = null;
								}
								Page.remove_box($(".loginBox"),true);
								$(".W_layer_mask").remove(); 
						},
						open:function(href){
								var iWidth = 800,
										iHeight = 600;
								var iTop = (window.screen.availHeight-30-iHeight)/2;
								var iLeft = (window.screen.availWidth-10-iWidth)/2;
								var position = 'width='+iWidth+',height='+iHeight+',top='+iTop+',left='+iLeft;
								this.oauth2_window_cache = window.open(href,'oauth2_window',position);
						}
				},
				open_window:function(href,width,height){
						var iWidth = width,
								iHeight = height;
						var iTop = (window.screen.availHeight-30-iHeight)/2;
						var iLeft = (window.screen.availWidth-10-iWidth)/2;
						var position = 'width='+iWidth+',height='+iHeight+',top='+iTop+',left='+iLeft;
						window.open(href,'open_window',position);
				},
				update_accountInfo:function(){
						$.ajax({
								url:'/login/accountInfo',
								type:"post",
								dataType:"json",
								data:{},
								success:function(json){
										var res = json.res;
										if(res){
											this.set_accountInfo(json);
										}
								}
						}); 
				},
				set_accountInfo:function(json){
					require(['text!templates/accountInfo.html'], function( accountInfoTemplate ){
							var empty_tpl = _.template( accountInfoTemplate );
							var box = empty_tpl(json);
							$("#accountInfo").html(box);
					})
				},
				signOut:function(){
						$.ajax({
								url:'/login/signout',
								type:"get",
								dataType:"json",
								data:{},
								success:function(json){
										var res = json.res,
												msg = json.msg;
										if(res){
												require(['text!templates/accountInfo.html'], function( accountInfoTemplate ){
														var empty_tpl = _.template( accountInfoTemplate );
														var box = empty_tpl({
																nickname:null
														});
														$("#accountInfo").html(box);
												})
												if(msg){
														Page.showTopTip(msg,'succ');
												};
										}else{
												if(msg){
														Page.showTopTip(msg,'error');
												};
										};
								}
						});
				}
		};

		(function(){

			var cache_url = null,
					cache_data = null;
			$.ajaxSetup({
					beforeSend: function(xhr, settings) {
						// 防止伪造攻击
						var token = $('meta[name="csrf-token"]').attr('content');
						if (token) xhr.setRequestHeader('X-CSRF-Token', token);
						// 避免重复提交
						var this_url = settings.url,
								this_data = settings.data;
						if(this_url==cache_url && this_data==cache_data){
							Page.showQZMsg('正在处理中...','warn');
							return false;
						}else{
							cache_url=this_url;
							cache_data=this_data;
						}
					},
					complete:function(){
						cache_url = null;
						cache_data = null;
					},
					error:function(info){
						if(info.status==400){
							Page.showLoginBox();
						}else{
							$(".W_layer_mask").remove();
							Page.showTopNotice('操作失败,错误码:'+info.status,'error');
						}
					}
			});
		})();

		$.fn.setCursorPosition = function(position){
		    if(this.lengh == 0) return this;
		    return $(this).setSelection(position, position);
		}

		$.fn.setSelection = function(selectionStart, selectionEnd) {
		    if(this.lengh == 0) return this;
		    input = this[0];

		    if (input.createTextRange) {
		        var range = input.createTextRange();
		        range.collapse(true);
		        range.moveEnd('character', selectionEnd);
		        range.moveStart('character', selectionStart);
		        range.select();
		    } else if (input.setSelectionRange) {
		        input.focus();
		        input.setSelectionRange(selectionStart, selectionEnd);
		    }

		    return this;
		}

		// 光标定位到输入框的末尾
		$.fn.focusEnd = function(){
				if(this.lengh == 0) return this;
				var val_length = this.val().length,
						selectionStart = val_length,
						selectionEnd = val_length;
		    input = this[0];
		    if (input.createTextRange) {
		        var range = input.createTextRange();
		        range.collapse(true);
		        range.moveEnd('character', selectionEnd);
		        range.moveStart('character', selectionStart);
		        range.select();
		    } else if (input.setSelectionRange) {
		        input.focus();
		        input.setSelectionRange(selectionStart, selectionEnd);
		    }
		    return this;
		}

		window.signIn = function(){
				Page.showLoginBox(null,null,'登录');
		};

		window.signOut = function(){
				Page.signOut();
		};

		window.open_oauth2_window = function(href){
				Page.oauth2_window.open(href);
		};

		// oauth2_callback
		window.oauth2_callback = function(success,txt,style){
				Page.oauth2_window.close();
				if(success){
						Page.todo_event.active();
						Page.update_accountInfo();
				}else{
						Page.todo_event.remove();
				}
				if(txt&&style){
						Page.showTopTip(txt,style);
				}
		};

		window.onmessage = function (e) {
			var opts = (e.data || '').split('@');
		  if ( opts[0] == 'cross_domain_authorize') {
		  	var remember_me = opts[1],
		  	    uid = opts[2],
		  	    secrue = opts[3];
				$.ajax({
						url:'/login/cross_domain_authorize',
						type:"post",
						dataType:"json",
						data:{
							remember_me:remember_me,
							uid:uid,
							secrue:secrue
						},
						success:function(json){
							  Page.oauth2_window.close();
								var res = json.res,
										msg = json.msg;
								if(res){
										Page.todo_event.active();
										Page.set_accountInfo(json);
										if(msg){
												Page.showTopTip(msg,'succ');
										};
								}else{
										if(msg){
												Page.showTopTip(msg,'error');
										};
								};
						}
				}); 
		  }
		};

		// close_template_box
		window.close_template_box = function(box,beautiful){
				$('.W_layer_mask').fadeOut();
				Page.remove_box(box,beautiful);
		};


		 $(function(){
				/**
				* 图片错误处理，加载默认图片
				**/
				$('img[rescue]').each(function(){
					var error = false,
							rescue_src = $(this).attr('rescue');
					if(!rescue_src){
						return
					}
					if (!this.complete) {
							error = true;
					}
					if (typeof this.naturalWidth != "undefined" && this.naturalWidth == 0) {
							error = true;
					}
					if(error){
							$(this).bind('error.replaceSrc',function(){
									this.src = rescue_src;
									$(this).unbind('error.replaceSrc');
							}).trigger('error.replaceSrc');
					}
				});
		 })

		return Page;
});