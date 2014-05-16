
class ApplicationController < Sinarey::Application

  helpers CoreHelper
  helpers ApplicationHelper

  include HomeRecommendServiceHelper

  set :views, ['application']
  
  before do
    @temp = {}
    @temp[:request_time] = Time.now
  end

  after do
    server_time = ((Time.now-@temp[:request_time])*1000).to_i
    writelog "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"+" | _#{response.status}_ | "+"#{server_time}".ljust(3)+"ms | #{get_client_ip}"+" | #{request.request_method.ljust(4)}"+" | #{request.url}"
  end

  error do
    dump_errors
    erb :page_500
  end

  def dispatch(controller,action)
    before_action(controller,action)
    @temp[:page] = "#{controller}##{action}"
  end

  def before_action(controller,action)
    set_current_user
  end

  def set_current_user
    set_current_uid
    @current_user = $profile_client.queryUserBasicInfo(@current_uid) if @current_uid
  end

  def set_current_uid
    token = cookies[Settings.cookies.token_label]
    if token
      remember_me = cookies[Settings.cookies.remember_me_label]
      login_flag_token = cookies[Settings.cookies.login_flag_label]
      thrift_login_help_info = Passport::Thrift::LoginHelpInfo.new({isCheckFlag: true, loginFlagToken: login_flag_token, userAgent: request.user_agent, ip: get_client_ip})
      if $login_client.checkLogin(token, remember_me, thrift_login_help_info)
        # 验证通过 返回uid
        @current_uid = token.split('&').first.to_i
        login_flag_token = token + '_' + Time.now.strftime("%Y-%m-%d %H:%M:%S")
        cookies[Settings.cookies.login_flag_label] = {value: login_flag_token, domain: parse_root_domain}
      else
        cookie_clean = []
        cookie_clean << "#{Settings.cookies.token_label}=#{token};Domain=#{parse_root_domain};Expires=Thu, 01-Jan-1970 00:00:10 GMT; Path=/"
        cookie_clean << "#{Settings.cookies.remember_me_label}=n;Domain=#{parse_root_domain};Expires=Thu, 01-Jan-1970 00:00:10 GMT; Path=/"
        cookie_clean << "#{Settings.cookies.thirdparty_label}=;Domain=#{parse_root_domain};Expires=Thu, 01-Jan-1970 00:00:10 GMT; Path=/"
        cookie_clean << "#{Settings.cookies.login_flag_label}=#{login_flag_token};Domain=#{parse_root_domain};Expires=Thu, 01-Jan-1970 00:00:10 GMT; Path=/"
        response['Set-Cookie'] = cookie_clean
      end
    end
  end

  def xhr_redirect_link(link)
    if request.xhr?
      return "#{link}.ajax"
    else
      return link
    end
  end

  # 已登录状态跳转到/#/xxxx 例如 已登录用户 get /demo1 => /#/demo1
  def redirect_to_root
    redirect_if_not_completed #新手引导
    @redirect_to_root = true
    if @current_uid and @current_uid > 0 and !request.xhr? # and request.fullpath != '/' 
      redirect "/##{request.fullpath}/" ,303
    end
    set_no_cache_header
  end

  def redirect_if_not_completed
    redirect(Settings.guider_url, 303) if @current_user and !@current_user.isCompleted
  end


  # 未登录跳登录页
  def redirect_to_login(from_path = '/')
    login_url = "#{Settings.login_url}?fromUri=#{request.scheme +'//' + request.env["SERVER_NAME"] + from_path}"
    if request.xhr?
      halt_js "location.href='#{login_url}';"
    else
      redirect(login_url, 303)
    end
  end

  def redirect_to_url(url = '/')
    if request.xhr?
      render_js "location.hash='#{url}';"
    else
      redirect(url, 303)
    end
  end

  # 未登录 如果异步请求返回400，非异步请求跳登录页
  def halt_400
    if request.xhr?
      halt 400, ''
    else
      redirect("#{Settings.login_url}?fromUri=#{request.url}", 303)
    end
  end

  # 没有权限访问
  def halt_403(hash = nil)
    if request.xhr?     
      halt render_json(hash)
    else
      halt 403, erb(:page_403)
    end
  end

  # 页面不存在
  def halt_404
    if request.xhr?
      halt erb_js(:page_404_js)
    end
    halt 404,erb(:page_404)
  end

  def halt_status0
    if request.xhr?
      halt erb_js(:page_status0_js)
    end
    halt erb(:page_status0)
  end

  def halt_status2
    if request.xhr?
      halt erb_js(:page_status2_js)
    end
    halt erb(:page_status2)
  end

  def halt_500
    if request.xhr?
      halt erb(:page_500_js)
    end
    halt erb(:page_500)
  end

  def halt_error(msg=nil)
    flash[:error_page_info] = msg.presence
    rdt_url = link_path('/error_page')
    if request.xhr?
      if request.post?
        halt render_json({res: true, msg: msg.to_s, redirect_to: rdt_url})
      else
        render_js "location.hash='#{rdt_url}';"
      end
    end
    redirect rdt_url,303
  end

  def halt_js(script)
    content_type 'text/javascript'
    halt script
  end

  def set_no_cache_header
    response.headers["Cache-Control"] = "no-cache, must-revalidate"
  end

  def erb_js(erb)
    content_type 'text/javascript'
    erb(erb,layout:false)
  end

  def render_json(json)
    json ||= {}
    content_type :json
    Oj.dump(json, mode: :compat)
  end

  def render_to_string(options)
    partial = options.delete(:partial)
    args = {layout:false}.merge(options)
    erb partial, args
  end

end