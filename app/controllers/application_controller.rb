
class ApplicationController < Sinarey::Application

  helpers CoreHelper
  helpers ApplicationHelper

  include HomeRecommendServiceHelper

  set :views, ['application']
  
  before do
    @temp = {}
    @temp[:request_time] = Time.now
    set_current_user
  end

  after do
    server_time = ((Time.now-@temp[:request_time])*1000).to_i
    writelog "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"+" | _#{response.status}_ | "+"#{server_time}".ljust(3)+"ms | #{get_client_ip}"+" | #{request.request_method.ljust(4)}"+" | #{request.url}"
  end

  error do
    dump_errors
    erb :'500'
  end

  not_found { erb :'404' }


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

  def set_current_user
    set_current_uid
    @current_user = $profile_client.queryUserBasicInfo(@current_uid) if @current_uid
  end

  def redirect_if_not_completed
    redirect Settings.guider_url if @current_user and !@current_user.isCompleted
  end

  def xhr_redirect_link(link)
    if request.xhr?
      return "#{link}.ajax"
    else
      return link
    end
  end

  # 已登录跳root
  def redirect_to_root
    @redirect_to_root = true
    if @current_uid and @current_uid > 0 and !request.xhr? # and request.fullpath != '/' 
      # 已登录用户 get /demo1 => /#/demo1
      redirect "/##{request.fullpath}/" 
    end
  end

  # 未登录跳登录页
  def redirect_to_login(from_path = '/')
    login_url = "#{Settings.login_url}?fromUri=#{request.protocol + request.host_with_port + from_path}"
    if request.xhr?
      render_js "location.href='#{login_url}';"
    else
      redirect login_url
    end
  end

  def redirect_to_url(url = '/')
    if request.xhr?
      render_js "location.hash='#{url}';"
    else
      redirect url, 301
    end
  end

  # 未登录 如果异步请求返回400，非异步请求跳登录页
  def halt_400
    if request.xhr?
      halt '', 400
    else
      redirect "#{Settings.login_url}?fromUri=#{request.protocol + request.host_with_port}/upload"
    end
  end

  # 没有权限访问
  def halt_403(hash = nil)
    if request.xhr?
      if hash
        render_json(hash)
      else       
        halt '', 403
      end
    else
      halt erb(:_page_403, layout: 'application'), 403
    end
  end

  # 页面不存在
  def halt_404
    if request.xhr?
      halt erb('_page_404.js')
    end
    halt erb(:_page_404)
  end

  def halt_status0
    if request.xhr?
      halt erb('_page_status0.js')
    end
    halt erb(:_page_status0)
  end

  def halt_status2
    if request.xhr?
      halt erb('_page_status2.js')
    end
    halt erb(:_page_status2)
  end

  def halt_500
    halt erb(:_page_500)
  end

  def register_page(controller,method)
    @temp[:page] = "#{controller}##{method}"
  end

  def set_no_cache_header
    response.headers["Cache-Control"] = "no-cache, must-revalidate"
  end

  def render_js(script)
    content_type 'text/javascript'
    halt script
  end

  def render_erb_js(erb)
    content_type 'text/javascript'
    erb(erb,layout:false)
  end

  def render_json(json)
    content_type :json
    Oj.dump(json, mode: :compat)
  end

  def render_to_string(options)
    partial = options.delete(:partial)
    args = {layout:false}.merge(options)
    erb partial, args
  end

end