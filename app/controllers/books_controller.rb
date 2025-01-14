class BooksController < ApplicationController
  def search
    @books = []
    title = params[:title_query]
    author = params[:author_query]

    if title.present? || author.present?
      @books = TimeHelper.time_function("search_arbookfind for title= #{title}, author= #{author}") do
        BookfindService.instance.search_by_title_and_author(params[:query])
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
