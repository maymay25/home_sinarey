
module Sinarey

  class Application < Sinatra::SinareyBase

    use Rack::Session::Cookie, { path:'/', expire_after:nil, key:Sinarey.session_key, secret:Sinarey.secret }

    helpers Sinatra::Cookies
    set :cookie_options, {path:'/',expires:1.year.from_now,httponly:false}

    set :default_encoding, 'utf-8'

    helpers Sinatra::ContentFor

    register WillPaginate::Sinatra
    register Sinatra::MultiRoute


    set :static, false

    #logger configure
    set :logging, nil

    set :erb, trim: '-'

    case Sinarey.env
    when 'production'
      set :show_exceptions, false
      set :raise_errors, false
      set :dump_errors, false
    else
      require "sinatra/sinarey_reloader"
      register Sinatra::SinareyReloader
      Dir["#{Sinarey.root}/app/*/*.rb"].each {|f| also_reload f }
      set :show_exceptions, true
      set :raise_errors, true
      set :dump_errors, false
    end

    #use custom logic for finding template files
    def find_template(views, name, engine, &block)
      paths = views.map { |d| Sinarey.root + '/app/views/' + d }
      Array(paths).each { |v| super(v, name, engine, &block) }
    end

    helpers do

      def escape_javascript(javascript)
        if javascript
          javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"'])/u) {|match| JS_ESCAPE_MAP[match] }
        else
          ''
        end
      end


      def app_logger
        current_day = Time.now.strftime('%Y-%m-%d')
        if (@@logger_day||=nil) != current_day
          @@app_logger = ::Logger.new(Sinarey.root+"/log/#{current_day}.log")
          @@logger_day = current_day
        end
        @@app_logger
      end

      if Sinarey.env=='development'
        def writelog(msg)
          puts msg.to_s
          app_logger << (msg.to_s + "\n")
        end
      else
        def writelog(msg)
          app_logger << (msg.to_s + "\n")
        end
      end

      def dump_errors
        boom = env['sinatra.error']
        if boom.present?
          msg = ["#{boom.class} - #{boom.message}:", *boom.backtrace].join("\n\t")
          writelog(msg)
        end
      end

    end
    
  end
end

JS_ESCAPE_MAP = {
  '\\'    => '\\\\',
  '</'    => '<\/',
  "\r\n"  => '\n',
  "\n"    => '\n',
  "\r"    => '\n',
  '"'     => '\\"',
  "'"     => "\\'"
}

JS_ESCAPE_MAP["\342\200\250".force_encoding(Encoding::UTF_8).encode!] = '&#x2028;'
JS_ESCAPE_MAP["\342\200\251".force_encoding(Encoding::UTF_8).encode!] = '&#x2029;'

class ApplicationController < Sinarey::Application ; end #init