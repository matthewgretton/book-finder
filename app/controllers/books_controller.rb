class BooksController < ApplicationController
  def search
    @books = []

    bookFinder = BookfindService.instance

    if params[:query].present?
      query = params[:query]
      @books = TimeHelper.time_function("search_arbookfind for query= #{query}") do
        bookFinder.search_by_title(query)
      end
    elsif params[:photos].present?
      TimeHelper.time_function("parse barcode and look up isbn") do
        photos = params[:photos].reject(&:blank?)

        isbns = photos.map do |photo|
          TimeHelper.time_function("scan_isbn for photo") do
            IsbnExtractor.extract(photo)
          end
        end.compact.uniq

        isbns.each do |isbn|
          @books.concat(TimeHelper.time_function("search_arbookfind for ISBN #{isbn}") do
            bookFinder.search_by_isbn(isbn)
          end)
        end
      end
    end

    render :search
  end
end
