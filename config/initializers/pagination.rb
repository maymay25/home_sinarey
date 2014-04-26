CustomPagination = Struct.new(:pagination_record_count,:current_page,:page_size)

#用于将sequel pagination对象转成will_paginate能处理的对象
class PaginateTemp

  def initialize(sequel_pagination)
    @current_page = sequel_pagination.current_page
    base_count,remain_count = sequel_pagination.pagination_record_count.divmod(sequel_pagination.page_size)
    base_count += 1 if remain_count > 0
    @total_pages = base_count
  end

  def current_page
    @current_page
  end

  def total_pages
    @total_pages
  end

  def previous_page
    @current_page - 1
  end

  def next_page
    @current_page + 1
  end

  def out_of_bounds?
    @current_page > @total_pages
  end

end

module WillPaginate
  module ViewHelpers
    class LinkRenderer < LinkRendererBase
    protected
      def page_number(page)
        if page == current_page
          "<a href='javascript:;' class='pagingBar_page on'>#{page}</a>"
        else
          if @options[:theme] == 'explore'
            "<a href='javascript:;' data-page='#{page}' class='pagingBar_page'>#{page}</a>"
          else
            "<a href='#{link_path(url(page))}' class='pagingBar_page'>#{page}</a>"
          end
        end
      end
      
      def gap
        %(<span>......</span>)
      end
      
      def previous_page
        num = @collection.current_page > 1 && @collection.current_page - 1
        previous_or_next_page(num, @options[:previous_label]||'上一页', 'pagingBar_page', 'prev')
      end
      
      def next_page
        num = @collection.current_page < total_pages && @collection.current_page + 1
        previous_or_next_page(num, @options[:next_label]||'下一页', 'pagingBar_page', 'next')
      end

      def previous_or_next_page(page, text, classname, rel=nil)
        if page
          rel_str = " rel='#{rel}'" if rel
          if @options[:theme] == 'explore'
            "<a href='javascript:;' data-page='#{page}' class='#{classname}'#{rel_str}>#{text}</a>"
          else
            "<a href='#{link_path(url(page))}' class='#{classname}'#{rel_str}>#{text}</a>"
          end
        end
      end

      def link_path(path)
        if @options[:link_path]
          '/#' << path
        else
          path
        end
      end


    end
  end
end
