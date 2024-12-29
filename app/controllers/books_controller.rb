class BooksController < ApplicationController
  def search
    @books = []

    if params[:query].present?
      @books = TimeHelper.time_function("search_arbookfind for query= #{params[:query]}") do
        BookfindService.instance.search_by_title(params[:query])
      end
    elsif params[:photos].present?
      TimeHelper.time_function("parse barcode and look up isbn") do
        photos = params[:photos].reject(&:blank?)

        # Process photos in parallel using threads
        threads = photos.map do |photo|
          Thread.new do
            TimeHelper.time_function("scan_isbn for photo") do
              IsbnExtractor.extract(photo)
            end
          end
        end

        isbns = threads.map(&:value).compact.uniq

        # Process ISBN searches in parallel
        isbn_threads = isbns.map do |isbn|
          Thread.new do
            TimeHelper.time_function("search_arbookfind for ISBN #{isbn}") do
              BookfindService.instance.search_by_isbn(isbn)
            end
          end
        end
        @books = isbn_threads.map(&:value).flatten
      end
    end

    render :search
  end
end
