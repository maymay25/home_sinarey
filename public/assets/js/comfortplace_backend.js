require(['jquery','underscore','page'], function( $, _, Page ){

    $(function(){

        $("#articles-mainbox").on('click','.verify-pass-article',function(){
            var $this = $(this);
            var article_id = $this.attr('data-articleId');
            if(!article_id){
                return
            }
            $.ajax({
                url:'/thecomfortplace/verify_pass_article',
                type:"post",
                dataType:"json",
                data:{
                    article_id: article_id
                },
                success:function(json){
                    var res = json.res,
                        msg = json.msg;
                    if(res){
                        Page.showTopTip('操作成功','succ');
                        $("#article-"+article_id).slideUp();
                    }else{
                        if(msg){
                            Page.showTopTip('操作失败','error');
                        };
                    };
                },
                error:function(info){
                    if(info.status==400){
                        Page.showTopTip('登录之后才能进行该操作','error');
                    }else{
                        Page.showTopTip('操作失败,错误码:'+info.status,'error');
                    }
                }
            });
        });

        $("#articles-mainbox").on('click','.verify-reject-article',function(){
            var $this = $(this);
            var article_id = $this.attr('data-articleId');
            if(!article_id){
                return
            }

            $.ajax({
                url:'/thecomfortplace/verify_reject_article',
                type:"post",
                dataType:"json",
                data:{
                    article_id: article_id
                },
                success:function(json){
                    var res = json.res,
                        msg = json.msg;
                    if(res){
                        Page.showTopTip('操作成功','succ');
                        $("#article-"+article_id).slideUp();
                    }else{
                        if(msg){
                            Page.showTopTip('操作失败','error');
                        };
                    };
                },
                error:function(info){
                    if(info.status==400){
                        Page.showTopTip('登录之后才能进行该操作','error');
                    }else{
                        Page.showTopTip('操作失败,错误码:'+info.status,'error');
                    }
                }
            });
        });

        $("#articles-mainbox").on('click','.verify-pass-comment',function(){
            var $this = $(this);
            var comment_id = $this.attr('data-commentId');
            if(!comment_id){
                return
            }

            $.ajax({
                url:'/thecomfortplace/verify_pass_comment',
                type:"post",
                dataType:"json",
                data:{
                    comment_id: comment_id
                },
                success:function(json){
                    var res = json.res,
                        msg = json.msg;
                    if(res){
                        Page.showTopTip('操作成功','succ');
                        $this.closest('.comfort-block-wrap').slideUp();
                    }else{
                        if(msg){
                            Page.showTopTip('操作失败','error');
                        };
                    };
                },
                error:function(info){
                    if(info.status==400){
                        Page.showTopTip('登录之后才能进行该操作','error');
                    }else{
                        Page.showTopTip('操作失败,错误码:'+info.status,'error');
                    }
                }
            });
        });

        $("#articles-mainbox").on('click','.verify-reject-comment',function(){
            var $this = $(this);
            var comment_id = $this.attr('data-commentId');
            if(!comment_id){
                return
            }

            $.ajax({
                url:'/thecomfortplace/verify_reject_comment',
                type:"post",
                dataType:"json",
                data:{
                    comment_id: comment_id
                },
                success:function(json){
                    var res = json.res,
                        msg = json.msg;
                    if(res){
                        Page.showTopTip('操作成功','succ');
                        $this.closest('.comfort-block-wrap').slideUp();
                    }else{
                        if(msg){
                            Page.showTopTip('操作失败','error');
                        };
                    };
                },
                error:function(info){
                    if(info.status==400){
                        Page.showTopTip('登录之后才能进行该操作','error');
                    }else{
                        Page.showTopTip('操作失败,错误码:'+info.status,'error');
                    }
                }
            });
        });

        $("#articles-mainbox").on('click','.eraser-user',function(){
            var $this = $(this);
            var uid = $this.attr('data-uid');
            if(!uid){
                return
            }

            Page.showConfirmBox($this,'确认要禁言该用户么？',function(){
                $('.W_layer_mask').remove();
                Page.remove_box($('.confirmBox'),true);
                $.ajax({
                    url:'/thecomfortplace/eraser_user',
                    type:"post",
                    dataType:"json",
                    data:{
                        uid: uid
                    },
                    success:function(json){
                        var res = json.res,
                            msg = json.msg;
                        if(res){
                            Page.showTopTip('操作成功','succ');
                            window.location.reload();
                        }else{
                            if(msg){
                                Page.showTopTip('操作失败','error');
                            };
                        };
                    },
                    error:function(info){
                        if(info.status==400){
                            Page.showTopTip('登录之后才能进行该操作','error');
                        }else{
                            Page.showTopTip('操作失败,错误码:'+info.status,'error');
                        }
                    }
                });
            })

        });

    });
});