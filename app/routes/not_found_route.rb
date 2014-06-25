
class NotFoundRoute < ApplicationController

  get '*' do
    status 404
    if request.xhr?
      halt erb_js(:page_404_js)
    else
      halt erb(:page_404)
    end
  end

  not_found do
    status 404
    if request.xhr?
      halt '404'
    else
      halt erb(:page_404)
    end
  end

  error do
    status 500
    if request.xhr?
      halt erb_js(:page_500_js)
    else
      halt erb :page_500
    end
  end

end
