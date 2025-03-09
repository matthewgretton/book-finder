# app/controllers/books_controller.rb
class BooksController < ApplicationController
  def search
    @books = []
    query = params[:query]

    if query.present?
      query = "\"#{query.gsub(/[“”]/, '"')}\""
      Rails.logger.info "search_arbookfind for query = #{query}"
      @books = TimeHelper.time_function("search_arbookfind for query = #{query}") do
        BookfindService.instance.search(query)
      end
    elsif params[:books].present?
      begin
        scanned_books = JSON.parse(params[:books])
        Rails.logger.info "Received scanned book details: #{scanned_books.inspect}"
        # For each scanned book (which should be a hash with keys "title" and "author"),
        # call adv_perform_search and then flatten the results.
        @books = @books = scanned_books.map do |book_query|
          # Convert string keys to symbols if necessary
          query_hash = book_query.respond_to?(:symbolize_keys) ? book_query.symbolize_keys : book_query
          ar_results = BookfindService.instance.adv_perform_search(query_hash)

          if ar_results.present?
            ar_results
          else
            # Create a placeholder with OpenLibrary data
            BookDetails.new(
              title: query_hash[:title],
              author: query_hash[:author],
              not_in_ar: true
            )
          end
        end.flatten
      rescue JSON::ParserError => e
        Rails.logger.error "Error parsing books parameter: #{e.message}"
        @books = []
      end
    end

    render :search
  end
end
