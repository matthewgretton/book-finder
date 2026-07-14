class BooksController < ApplicationController
  def search
    @books = []
    @pending_isbns = []
    query = params[:query]

    if query.present?
      query = query.gsub(/[""]/, '"')
      Rails.logger.info "search_arbookfind for query = #{query}"

      @books = TimeHelper.time_function("search_arbookfind for query = #{query}") do
        BookfindService.instance.search(query)
      end
    elsif params[:isbns].present?
      # Render placeholder rows immediately; each ISBN is looked up by its
      # own follow-up request (see #isbn_lookup) so results stream in.
      @pending_isbns = params[:isbns].split(",").map { |isbn| isbn.gsub(/\D/, "") }.reject(&:empty?).uniq
    end

    render :search
  end

  def isbn_lookup
    isbn = params[:isbn].to_s.gsub(/\D/, "")

    books = TimeHelper.time_function("search_arbookfind for ISBN #{isbn}") do
      BookfindService.instance.search_by_isbn(isbn)
    end

    render turbo_stream: turbo_stream.replace(
      "isbn-row-#{isbn}",
      partial: "books/isbn_result",
      locals: { books: books, isbn: isbn }
    )
  end

  def details
    details = BookfindService.instance.fetch_details(params[:path].to_s)

    if details
      render json: details
    else
      head :unprocessable_entity
    end
  end
end
