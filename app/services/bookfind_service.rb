class BookfindService
  FORM_FIELDS = {
    # Basic search fields
    search_term: "ctl00$ContentPlaceHolder1$txtKeyWords",
    isbn: "ctl00$ContentPlaceHolder1$txtISBN",
    submit: "ctl00$ContentPlaceHolder1$btnDoIt",
    # Advanced search fields
    title: "ctl00$ContentPlaceHolder1$txtTitle",
    author: "ctl00$ContentPlaceHolder1$txtAuthor"
  }.freeze

  class << self
    def instance
      @instance ||= new
    end

    private :new

    def search(query)
      instance.search(query)
    end

    def search_by_isbn(isbn)
      instance.search_by_isbn(isbn)
    end
  end

  def initialize
    setup_sessions
  end

  def search(query)
    perform_search(query)
  end

  def search_by_isbn(isbn)
    result = find_book_by_isbn(isbn)
    Rails.logger.info "OpenLibrary result = #{result}"
    return [] if result.nil?

    ar_results = adv_perform_search(result)

    if ar_results.present?
      ar_results
    else
      # Return placeholder with OpenLibrary data if not in AR
      [ BookDetails.new(
        title: result[:title],
        author: result[:author],
        not_in_ar: true
      ) ]
    end
  end

  def find_books_by_query(query)
    # Remove quotes from query for OpenLibrary search
    clean_query = query.gsub(/[""]/, "").strip

    # Search OpenLibrary by title or author
    response = HTTParty.get(
      "https://openlibrary.org/search.json",
      query: {
        q: query,
        language: "eng"
      }
    )

    return [] unless response.success? && response["docs"].present?

    # Process results
    bob = response["docs"].map do |book|
      {
        title: book["title"],
        author: book.dig("author_name", 0) || "Unknown Author"
      }
    end.uniq { |book| [ book[:title], book[:author] ] }

    puts bob
    bob
  end

  # Modify the existing search method to use the new flow
  def search(query)
    # First try to find books on OpenLibrary
    Rails.logger.info "Searching OpenLibrary for query = #{query}"
    open_library_results = TimeHelper.time_function("search_openlibrary for query = #{query}") do
      find_books_by_query(query)
    end

    return [] if open_library_results.empty?

    # For each OpenLibrary result, check AR BookFind
    results = open_library_results.map do |book_data|
      ar_results = adv_perform_search(book_data)

      if ar_results.present?
        # If found in AR, use those results
        ar_results
      else
        # If not found in AR, create a placeholder with OpenLibrary data
        BookDetails.new(
          title: book_data[:title],
          author: book_data[:author],
          not_in_ar: true
        )
      end
    end

    results.flatten
  end

  def adv_perform_search(search_params)
    execute_search(:advanced) do |form|
      # Clear existing values
      FORM_FIELDS.slice(:title, :author).each do |_, field|
        form[field] = ""
      end

      # Set new search parameters
      search_params.each do |param, value|
        field = FORM_FIELDS[param]
        form[field] = value if field && value.present?
      end
    end
  end

  private

    def setup_sessions
      @sessions = {
        basic: setup_single_session("default.aspx"),
        advanced: setup_single_session("advanced.aspx")
      }
    end

    def setup_single_session(endpoint)
      Rails.logger.info "Setting up AR Bookfind session for #{endpoint}"
      agent = Mechanize.new
      page = agent.get("https://www.arbookfind.co.uk/#{endpoint}")

      if form = page.form_with(name: "form1")
        radio = form.radiobutton_with(value: "radParent")
        if radio
          radio.check
          page = form.submit(form.button_with(name: "btnSubmitUserType"))
        end
      end

      { page: page, agent: agent }
    end

    def perform_search(search_term)
      execute_search(:basic) do |form|
        form[FORM_FIELDS[:search_term]] = search_term
      end
    end



    def execute_search(session_type)
      begin
        session = @sessions[session_type]
        form = session[:page].form_with(name: "aspnetForm")

        if form
          yield(form)
          submit_button = form.button_with(name: FORM_FIELDS[:submit])

          if submit_button
            results_page = form.submit(submit_button)
            parse_results(session[:agent], results_page)
          else
            Rails.logger.error "No submit button found"
            []
          end
        else
          Rails.logger.error "No form found"
          []
        end
      rescue OpenSSL::SSL::SSLError, Mechanize::Error, Net::HTTP::Persistent::Error => e
        Rails.logger.error "Search error: #{e.message}"
        @sessions[session_type] = setup_single_session(session_type == :basic ? "default.aspx" : "advanced.aspx")
        retry
      end
    end

    def parse_results(agent, page)
      doc = Nokogiri::HTML(page.body)

      no_results = doc.at_css("span#ctl00_ContentPlaceHolder1_lblNoResults")
      return [] if no_results && no_results.text.strip.present?

      book_details = doc.css("table.book-result")
      book_details.map { |detail| extract_book_from_details(agent, detail) }.compact
    end

    def extract_book_from_details(agent, book_detail)
      detail_cell = book_detail.at_css("td.book-detail")
      return nil unless detail_cell

      title_link = detail_cell.at_css('a[href*="bookdetail.aspx"]')
      return nil unless title_link

      title = title_link.text.strip
      meta_paragraph = detail_cell.at_css("p")
      author = meta_paragraph ? meta_paragraph.text.strip.split("\n").first&.strip : "Unknown Author"

      if title_link["href"]
        detail_link = title_link["href"]
        detail_page_url = "https://www.arbookfind.co.uk/#{detail_link}"
        detail_page = agent.get(detail_page_url)
        detail_doc = Nokogiri::HTML(detail_page.body)

        BookDetails.new(
          title: title,
          author: author,
          series: extract_series(detail_doc),
          word_count: extract_word_count(detail_doc),
          **extract_other_details(meta_paragraph)
        )
      end
    end

    def extract_series(doc)
      series_elements = doc.css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblSeriesLabel")
      series_elements.map { |element| element.text.strip.chomp(";") }.join(", ")
    end

    def extract_word_count(doc)
      word_count_element = doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblWordCount")
      word_count_element ? word_count_element.text.strip.to_i : 0
    end

    def extract_other_details(meta_paragraph)
      return {} unless meta_paragraph
      paragraph_text = meta_paragraph.text.strip

      {
        atos_book_level: extract_book_level(paragraph_text),
        interest_level: extract_interest_level(paragraph_text),
        ar_points: extract_ar_points(paragraph_text)
      }
    end

    def extract_book_level(text)
      bl_text = text.match(/BL: (\d+\.\d+)/)
      bl_text ? bl_text[1].to_f : 0.0
    end

    def extract_interest_level(text)
      interest_level_match = text.match(/IL: (\w+)/)
      interest_level_match ? interest_level_match[1] : "Unknown"
    end

    def extract_ar_points(text)
      ar_points_match = text.match(/AR Pts: (\d+\.\d+)/)
      ar_points_match ? ar_points_match[1].to_f : 0.0
    end

    def find_book_by_isbn(isbn)
      response = HTTParty.get(
        "https://openlibrary.org/api/books",
        query: {
          bibkeys: "ISBN:#{isbn}",
          format: "json",
          jscmd: "data"
        }
      )

      # OpenLibrary returns a hash with key "ISBN:#{isbn}"
      book_data = response["ISBN:#{isbn}"]
      return nil unless book_data

      {
        title: book_data["title"],
        author: book_data.dig("authors", 0, "name")
      }
    end
end
