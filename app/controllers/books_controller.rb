class BooksController < ApplicationController
  def search
    @books = []
    query = params[:query]

    if query.present?

      query = query.gsub(/[“”]/, '"')
      Rails.logger.info "search_arbookfind for query = #{query}"

      @books = TimeHelper.time_function("search_arbookfind for query = #{query}") do
        BookfindService.instance.search(query)
      end
    elsif params[:isbns].present?
      isbns = params[:isbns].split(",")

      isbn_threads = isbns.map do |isbn|
        Thread.new do
          TimeHelper.time_function("search_arbookfind for ISBN #{isbn}") do
            BookfindService.instance.search_by_isbn(isbn)
          end
        end
      end
      @books = isbn_threads.map(&:value).flatten
    end

    render :search
  end
end
