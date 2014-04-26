var MoreLinksShowHandles,
    ShowMoreLinks='';
function showMoreLinks(e,t){clearTimeout(MoreLinksShowHandles),document.getElementById(e).style.display="block",t&&(document.getElementById(e+"Handle").className=t),e!=ShowMoreLinks&&ShowMoreLinks!=""&&(document.getElementById(ShowMoreLinks).style.display="none",t&&(document.getElementById(e+"Handle").className=t)),ShowMoreLinks=e}
function hideMoreLinks(e,t){MoreLinksShowHandles=setTimeout(function(){document.getElementById(e).style.display="none",t&&(document.getElementById(e+"Handle").className=t)},500)}

window.change_list = (function() {
    var _last, func = function(type) {
        if (_last) {
          $('#_'+_last+'_tab').removeClass('selected');
          $('#_'+_last+'_posts').hide();
          console.info(_last);
        }
        $('#_' + type + '_tab').addClass('selected');
        $('#_' + type + '_posts').show();
        _last = type;
    };
    func('related');

    return func
})();


$(function(){

  var isIE6 = $('body').attr('id')=='ie6';

  var loading  = $("#LOADING");
  loading.css("width","100%").addClass('done');
  setTimeout(function(){
      loading.hide();
  },1000);


  $('.placeholding-input>.text-input').bind('input',function(){
    $(this).parent().addClass('hasome');
  });

  $('.placeholding-input>.text-input').bind('blur',function(){
    var $this = $(this);
    if($this.val()=="")
      $this.parent().removeClass('hasome');
  });


  $('#scroll-to-top').click(function(event){
    $('html, body').animate({scrollTop:0}, 300);
  });
  $(window).scroll(function(event){
    if($(this).scrollTop() > 400){
      if($('#scroll-to-top').hasClass('hide')){
        $('#scroll-to-top').removeClass('hide');
      }
    }else{
      $('#scroll-to-top').addClass('hide');
    }
  });


  $.fn.hoverDelay = function(options){
      var defaults = {
          hoverDuring: 200,
          outDuring: 200,
          hoverEvent: function(){
              $.noop();
          },
          outEvent: function(){
              $.noop();    
          }
      };
      var sets = $.extend(defaults,options || {});
      var hoverTimer, outTimer;
      return $(this).each(function(){
          $(this).hover(function(){
              clearTimeout(outTimer);
              hoverTimer = setTimeout(sets.hoverEvent, sets.hoverDuring);
          },function(){
              clearTimeout(hoverTimer);
              outTimer = setTimeout(sets.outEvent, sets.outDuring);
          });    
      });
  }

  $("#OpenMoreLinks,#MoreLinks").hoverDelay({
    hoverEvent: function(){
      showMoreLinks("MoreLinks",'');
    },
    outDuring: 1,
    outEvent: function(){
      hideMoreLinks("MoreLinks",'');
    }
  });


  // 新闻轮播

  var slide = function(index){
    var $module = $("#news-widget-slide");
    if(index==$module.data('index')){
      return
    }
    $module.data('index',index);
    var $ctrl_list = $(".widget-slide-ctrl-nav li");
    $ctrl_list.removeClass('current');
    $ctrl_list.eq(index).addClass('current');
    var $list = $(".widget-slide-contents-piclist li");
    $list.hide();
    $list.eq(index).fadeIn();
  }

  var newsSlide = {
    init:function(){
      $("#news-widget-slide").bind('mouseenter',function(){
        $(".widget-slide-order").css('visibility','visible');
      })
      $("#news-widget-slide").bind('mouseleave',function(){
        $(".widget-slide-order").css('visibility','hidden');
      })

      $(".widget-slide-ctrl-nav li").bind('mouseenter',function(){
        var index = $(this).data('index');
        slide(index);
      })

      $(".widget-slide-order").bind('click',function(){

        var length = $(".widget-slide-ctrl-nav li").length,
            n = $("#news-widget-slide").data("index"),
            order = $(this).data("order");
        if(order=="prev"){
          if(0+n>0){index = 0+n-1;}
          else{index = length-1;}
        }else if(order="next"){
          if(1+n<length){index = n+1;}
          else{index = 0;}
        }else{return false;}
        slide(index);
      })

    }

  }

  newsSlide.init();


})

