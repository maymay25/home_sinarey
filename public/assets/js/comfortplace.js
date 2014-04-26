require(['jquery','underscore','page'], function( $, _, Page ){


	$('.link_root').bind('click',function(){
	    // Page.showQZMsg('正在建设中，敬请期待...','succ');
	    window.location.href='http://www.suixin365.com';
	})

	$('#comfort_logo').bind('click',function(){

	    var $body = $('body');
	    //人人正在审核中，先屏蔽
	    if($body.hasClass('renrenBody')){
	        return
	    }

	    if($body.hasClass('iframe')){
	        window.open("http://www.suixin365.com/comfort/");
	    }
	})


	$('#shareOutBtn').bind('click',function(){
	    var $this = $(this);
	    var shareTo = $(this).attr('shareTo');
	    Page.showShareBox(shareTo,function(box,ele){
	      var $box = $(box),
	          $ele = $(ele);
	      var textarea = $("#shareBox").find('textarea');
	      var content = textarea.val();
	      if(!content||$.trim(content)==''){
	        var commit_btn = $box.find('button.commit');
	        Page.showTipBox(commit_btn,'请输入分享内容','warn',1500);
	        Page.shine(textarea);
	        textarea.focus();
	        return
	      }

	      $.ajax({
	          url:'/thecomfortplace/share_out',
	          type:"post",
	          dataType:"json",
	          data:{
	              content: content
	          },
	          success:function(json){
	              var res = json.res,
	                  msg = json.msg,
	                  htm = json.htm,
	                  article_id = json.article_id;
	              if(res){
	                  if(msg){
	                      Page.showQZMsg(msg,'succ');
	                  }
	              }else{
	                  if(msg){
	                      Page.showQZMsg(msg,'error');
	                  }
	              };
	              Page.remove_box($(".shareBox"));
	              $(".W_layer_mask").remove(); 
	          },
	          error:function(info){
	              if(info.status==400){
	                Page.showLoginBox($ele,null,null);
	              }else{
	                Page.remove_box($(".shareBox"));
	                $(".W_layer_mask").remove();
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	              }
	          }
	      });
	    })
	})

	$('#open-ask-comfort').bind('click',function(){
	    $("#ask-comfort").toggle();
	    $("#input-article").focus();
	});

	$('#cancle-article').bind('click',function(){
	    $("#ask-comfort").hide();
	    $("#comfort").show();
	});

	$("#submit-article").bind('click',function(){
	    var $eleArticle = $('#input-article'),
	        $this = $(this);
	    var article = $eleArticle.val().replace('在这里倾诉你的烦恼...','');
	    article = $.trim(article);
	    if(article==''){
	        Page.shine($eleArticle);
	        $eleArticle.focus();
	        return
	    };
	    var downcase_article = article.toLocaleLowerCase();
	    if(downcase_article.indexOf('http://')>-1){
	        Page.showTipBox($this,'请不要输入网址','warn',1500);
	        return
	    }

	    $.ajax({
	        url:'/thecomfortplace/create_article',
	        type:"post",
	        dataType:"json",
	        data:{
	            article: article
	        },
	        success:function(json){
	            var res = json.res,
	                msg = json.msg,
	                htm = json.htm,
	                article_id = json.article_id;
	            if(res){
	                $('#input-article').val('');
	                $("#articles-mainbox").prepend(htm);
	                $("#article-"+article_id).slideDown();
	                if(msg){
	                    Page.showQZMsg(msg,'succ');
	                }
	            }else{
	                if(msg){
	                    Page.showQZMsg(msg,'error');
	                }
	            };
	            $("#ask-comfort").hide();
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,true,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.submit-comment',function(){
	    var $this=$(this);
	    var article_id = $this.attr('data-articleId');
	    if(!article_id){
	        return
	    };
	    var $eleComment = $('.input-comment[data-articleId='+article_id+']');
	    var comment = $eleComment.val().replace('继续说点什么...','').replace('对他说点什么...','');
	    comment = $.trim(comment);
	    if(comment==''){
	        // Page.showTipBox($this,'请输入内容','warn',1500);
	        Page.shine($eleComment);
	        $eleComment.focus();
	        return
	    };
	    var downcase_comment = comment.toLocaleLowerCase();
	    if(downcase_comment.indexOf('http://')>-1){
	        Page.showTipBox($this,'请不要输入网址','warn',1500);
	        return
	    }

	    $.ajax({
	        url:'/thecomfortplace/create_comment',
	        type:"post",
	        dataType:"json",
	        data:{
	            article_id: article_id,
	            comment: comment
	        },
	        success:function(json){
	            var res = json.res,
	                msg = json.msg,
	                htm = json.htm,
	                article_id = json.article_id,
	                comment_id = json.comment_id;
	            $eleComment.val('');
	            if(res){
	                $("#comments-"+article_id).append(htm);
	                $("#comment-"+comment_id).slideDown('normal');
	                if(msg){
	                    Page.showQZMsg(msg,'succ');
	                };
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.load_more_comments',function(){
	    var $this = $(this);
	    var article_id = $this.attr('data-articleId'),
	        count = $this.attr('data-remainCount'),
	        page = $this.attr('data-nextpage');
	    if(!article_id || !count || !page){
	        return
	    };
	    $.ajax({
	        url:'/thecomfortplace/load_more_comments',
	        type:"post",
	        dataType:"json",
	        data:{
	            remain_count: count,
	            article_id: article_id,
	            page: page
	        },
	        success:function(json){
	            var res = json.res,
	                htm = json.htm,
	                next_page = json.next_page,
	                remain_count = json.remain_count,
	                msg = json.msg;
	            var current_next_page = $this.attr('data-nextpage');
	            if(current_next_page == next_page){
	                return
	            }
	            if(res && htm){
	                $this.before(htm);

	                $(".comment.slide").slideDown("normal",function(){
	                    $(this).removeClass('slide');
	                });
	                if(remain_count>0){
	                    $this.attr('data-remainCount',remain_count).attr('data-nextpage',next_page);
	                    $this.html('<a href="javascript:;">• • • 还有'+remain_count+'条评论，点击查看>> • • •</a>');
	                }else{
	                    $this.remove();
	                }
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.anwei-article.anwei',function(){
	    var $this = $(this);
	    var article_id = $this.attr('data-articleId');
	    if(!article_id){
	        return
	    }
	    $.ajax({
	        url:'/thecomfortplace/create_anwei',
	        type:"post",
	        dataType:"json",
	        data:{
	            article_id: article_id
	        },
	        success:function(json){
	            var res = json.res,
	                flag = json.flag,
	                anwei_count = json.anwei_count,
	                msg = json.msg;
	            if(res){
	                $this.removeClass('anwei').addClass('already');
	                if(flag=='add'){
	                    Page.showIconDynamic($this,'icon-heart','on');
	                    $(".count[data-articleId="+article_id+"]").html('+'+anwei_count).attr('title',''+anwei_count+'人关心');
	                }
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.anwei-article.already',function(){
	    var $this = $(this);
	    var article_id = $this.attr('data-articleId');
	    if(!article_id){
	        return
	    }
	    $.ajax({
	        url:'/thecomfortplace/cancle_anwei',
	        type:"post",
	        dataType:"json",
	        data:{
	            article_id: article_id
	        },
	        success:function(json){
	            var res = json.res,
	                flag = json.flag,
	                anwei_count = json.anwei_count,
	                msg = json.msg;
	            if(res){
	                $this.removeClass('already').addClass('anwei');
	                if(flag=='reduce'){
	                    Page.showIconDynamic($this,'icon-heart','');
	                    if(anwei_count>0){
	                        $(".count[data-articleId="+article_id+"]").html('+'+anwei_count).attr('title',''+anwei_count+'人关心');
	                    }else{
	                        $(".count[data-articleId="+article_id+"]").html('&nbsp;').attr('title','');
	                    }
	                }
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.upvote-comment.upvote',function(){
	    var $this = $(this);
	    var comment_id = $this.attr('data-commentId');
	    if(!comment_id){
	        return
	    }
	    $.ajax({
	        url:'/thecomfortplace/create_vote',
	        type:"post",
	        dataType:"json",
	        data:{
	            comment_id: comment_id
	        },
	        success:function(json){
	            var res = json.res,
	                flag = json.flag,
	                vote_count = json.vote_count,
	                msg = json.msg;
	            if(res){
	                $this.removeClass('upvote').addClass('already');
	                if(flag=='add'){
	                    Page.showIconDynamic($this,'icon-smile','on');
	                    $(".count[data-commentId="+comment_id+"]").html('+'+vote_count).attr('title',''+vote_count+'人满意');
	                }
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.upvote-comment.already',function(){
	    var $this = $(this);
	    var comment_id = $this.attr('data-commentId');
	    if(!comment_id){
	        return
	    }
	    $.ajax({
	        url:'/thecomfortplace/cancle_vote',
	        type:"post",
	        dataType:"json",
	        data:{
	            comment_id: comment_id
	        },
	        success:function(json){
	            var res = json.res,
	                flag = json.flag,
	                vote_count = json.vote_count,
	                msg = json.msg;
	            if(res){
	                $this.removeClass('already').addClass('upvote');
	                if(flag=='reduce'){
	                    Page.showIconDynamic($this,'icon-smile','');
	                    if(vote_count>0){
	                        $(".count[data-commentId="+comment_id+"]").html('+'+vote_count).attr('title',''+vote_count+'人满意');
	                    }else{
	                        $(".count[data-commentId="+comment_id+"]").html('&nbsp;').attr('title','');
	                    }
	                }
	            }else{
	                if(msg){
	                    Page.showTipBox($this,msg,'warn',1500);
	                };
	            };
	        },
	        error:function(info){
	            if(info.status==400){
	                Page.showLoginBox($this,null,null);
	                Page.todo_event.create({'dom':$this,'event':'click'});
	            }else{
	                Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	            }
	        }
	    });
	});

	$("#articles-mainbox").on('click','.delete-article',function(){
	    var $this = $(this);
	    var article_id = $this.attr('data-articleId');
	    if(!article_id){
	        return
	    }

	    Page.showConfirmBox($this,'确认要删除这篇倾述？',function(){
	        $('.W_layer_mask').remove();
	        Page.remove_box($('.confirmBox'),true);
	        $.ajax({
	            url:'/thecomfortplace/delete_article',
	            type:"post",
	            dataType:"json",
	            data:{
	                article_id: article_id
	            },
	            success:function(json){
	                var res = json.res,
	                    msg = json.msg;
	                if(res){
	                    if(msg){
	                        Page.showQZMsg(msg,'succ');
	                    }
	                    $("#article-"+article_id).slideUp();
	                }else{
	                    if(msg){
	                        Page.showQZMsg(msg,'error');
	                    };
	                };
	            },
	            error:function(info){
	                if(info.status==400){
	                    Page.showLoginBox($this,null,null);
	                    Page.todo_event.create({'dom':$this,'event':'click'});
	                }else{
	                    Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	                }
	            }
	        });
	    });

	});

	$("#articles-mainbox").on('click','.delete-comment',function(){
	    var $this = $(this);
	    var comment_id = $this.attr('data-commentId');
	    if(!comment_id){
	        return
	    }


	    Page.showConfirmBox($this,'确认要删除这条回复？',function(){
	        $('.W_layer_mask').remove();
	        Page.remove_box($('.confirmBox'),true);
	        $.ajax({
	            url:'/thecomfortplace/delete_comment',
	            type:"post",
	            dataType:"json",
	            data:{
	                comment_id: comment_id
	            },
	            success:function(json){
	                var res = json.res,
	                    msg = json.msg;
	                if(res){
	                    if(msg){
	                        Page.showQZMsg(msg,'succ');
	                    }
	                    $("#comment-"+comment_id).slideUp();
	                }else{
	                    if(msg){
	                        Page.showQZMsg(msg,'error');
	                    };
	                };
	            },
	            error:function(info){
	                if(info.status==400){
	                    Page.showLoginBox($this,null,null);
	                    Page.todo_event.create({'dom':$this,'event':'click'});
	                }else{
	                    Page.showQZMsg('操作失败,错误码:'+info.status,'error');
	                }
	            }
	        });
	    });
	});

});