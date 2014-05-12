
class NotFoundRoute < ApplicationController

  def not_found_response
    if request.xhr?
      erb :page_404_js
    else
      erb :page_404
    end
  end

  def rescue_response
    if request.xhr?
      erb :page_500_js
    else
      erb :page_500
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
