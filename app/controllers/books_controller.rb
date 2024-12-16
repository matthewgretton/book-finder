
class BooksController < ApplicationController
  def initialize
    super
    @bookfind_service = BookfindService.new
  end

  def search
    @books = []

    if params[:query].present?
      query = params[:query]
      @books = TimeHelper.time_function("search_arbookfind for query= #{query}") do
        @bookfind_service.search_by_title(query)
      end
    elsif params[:photos].present?
      photos = params[:photos].reject(&:blank?)
      isbns = photos.map do |photo|
        TimeHelper.time_function("scan_isbn for photo") do
          IsbnExtractor.extract(photo)
        end
      end.uniq

      isbns.each do |isbn|
        @books.concat(TimeHelper.time_function("search_arbookfind for ISBN #{isbn}") do
          @bookfind_service.search_by_isbn(isbn)
        end)
      end
    end

    render :search
  end
end
