
class NotFoundRoute < ApplicationController

  def not_found_response
    if request.get?
      erb :'404'
    else
      content_type=:json
      render_json({res:false,flag:'404'})
    end
  end

  def rescue_response
    if request.get?
      erb :'500'
    else
      content_type=:json
      render_json({res:false,flag:'500'})
    end
  end

  get '*' do
    status 404
    not_found_response
  end

  not_found {
    not_found_response
  }

  errors {
    rescue_response
  }

end
