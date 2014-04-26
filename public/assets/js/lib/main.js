require(["jquery","plugin/jquery.easing","plugin/jquery.megamenu"], function(){

    /*  全局初始化的脚本写在这里  */

    $(function () {

        /*  'megamenu' START */
        $("#megamenu").megamenu({
          fx: "backout",
          speed: 1000
        });
        /*  'megamenu' FINISH */

        /* 回到首页 */
        $(".link_root").bind('click',function(){
            window.location.href = '/';
        })

        /*  '返回顶部' START */

        $("#back-top a").click(function () {
            $("html,body").animate({
                "scrollTop": "0"
            }, "slow");
        })

        $(window).scroll(function () {
            var $top = $(window).scrollTop();
            var $navigation = $("#header-container");
            if ($top > 300) {
                $("#back-top").fadeIn(200);
            }else{
                $("#back-top").fadeOut(200); 
            }

        })
        /*  '返回顶部' FINISH */

    })



});