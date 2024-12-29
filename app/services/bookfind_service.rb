class BookfindService
  FORM_FIELDS = {
    title: "ctl00$ContentPlaceHolder1$txtTitle",
    author: "ctl00$ContentPlaceHolder1$txtAuthor",
    series: "ctl00$ContentPlaceHolder1$txtSeries",
    publisher: "ctl00$ContentPlaceHolder1$txtPublisher",
    isbn: "ctl00$ContentPlaceHolder1$txtISBN",
    quiz_released_in_last_days: "ctl00$ContentPlaceHolder1$lstQuizReleasedInLastHowManyDays",
    quiz_type: "ctl00$ContentPlaceHolder1$lstQuizType",
    interest_level: "ctl00$ContentPlaceHolder1$lstInterestLevel",
    book_level_min: "ctl00$ContentPlaceHolder1$txtBLMin",
    book_level_max: "ctl00$ContentPlaceHolder1$txtBLMax",
    sort: "ctl00$ContentPlaceHolder1$lstSort",
    submit: "ctl00$ContentPlaceHolder1$btnDoIt"
  }.freeze

  class << self
    def instance
      @instance ||= new
    end

    private :new

    def search_by_title(title)
      instance.search_by_title(title)
    end

    def search_by_isbn(isbn)
      instance.search_by_isbn(isbn)
    end
  end

  def initialize
    setup_session
  end

  def search_by_title(title)
    search_params = { title: title }
    perform_search(search_params)
  end

  def search_by_isbn(isbn)
    result = find_book_by_isbn(isbn)
    return [] if result.nil?

    title = result[:title]
    search_params = { title: title }
    perform_search(search_params)
  end

  private

    def setup_session
      Rails.logger.info "Setting up AR Bookfind session"
      agent = Mechanize.new

      page = agent.get("https://www.arbookfind.co.uk/advanced.aspx")

      if form = page.form_with(name: "form1")
        form.radiobutton_with(value: "radParent").check
        page = form.submit(form.button_with(name: "btnSubmitUserType"))
      end

      @search_page = page
      @agent = agent
    end

    def perform_search(search_params)
      begin
        form = @search_page.form_with(name: "aspnetForm")
        search_params.each do |param, value|
          field = FORM_FIELDS[param]
          form[field] = value if field && value.present?
        end

        results_page = form.submit(form.button_with(name: FORM_FIELDS[:submit]))
        parse_results(results_page)
      rescue OpenSSL::SSL::SSLError, Mechanize::Error, Net::HTTP::Persistent::Error
        Rails.logger.info "SSL Error reloading agent..."
        @agent = nil
        @search_page = nil
        setup_session
        retry
      end
    end

    def parse_results(page)
      doc = Nokogiri::HTML(page.body)
      book_details = doc.css("td.book-detail")
      book_details.map { |detail| extract_book_from_details(detail) }
    end

    def extract_book_from_details(book_detail)
      title = book_detail.at_css("a#book-title").text.strip
      author = book_detail.at_css("p").text.strip.split("\n").first.strip

      # Get the detail page link and fetch additional information
      detail_link = book_detail.at_css("a#book-title")["href"]
      detail_page_url = "https://www.arbookfind.co.uk/#{detail_link}"
      detail_page = @agent.get(detail_page_url)
      detail_doc = Nokogiri::HTML(detail_page.body)

      # Extract Series
      series_elements = detail_doc.css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblSeriesLabel")
      series = series_elements.map { |element| element.text.strip.chomp(";") }.join(", ")

      # Extract Word Count
      word_count_element = detail_doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblWordCount")
      word_count = word_count_element ? word_count_element.text.strip.to_i : 0

      paragraph_text = book_detail.at_css("p").text

      bl_text = paragraph_text.match(/BL: (\d+\.\d+)/)
      atos_book_level = bl_text ? bl_text[1].to_f : 0.0

      interest_level_match = paragraph_text.match(/IL: (\w+)/)
      interest_level = interest_level_match ? interest_level_match[1] : "Unknown"

      ar_points_match = paragraph_text.match(/AR Pts: (\d+\.\d+)/)
      ar_points = ar_points_match ? ar_points_match[1].to_f : 0.0

      Book.new(
        title: title,
        author: author,
        series: series,
        atos_book_level: atos_book_level,
        interest_level: interest_level,
        ar_points: ar_points,
        word_count: word_count
      )
    end

    def find_book_by_isbn(isbn)
      response = HTTParty.get(
        "https://www.googleapis.com/books/v1/volumes",
        query: {
          q: "isbn:#{isbn}",
          maxResults: 1,
          fields: "items(volumeInfo(title,authors))"
        }
      )

      return nil if response["items"].nil? || response["items"].empty?

      volume_info = response["items"].first["volumeInfo"]
      {
        title: volume_info["title"],
        author: volume_info["authors"]&.first
      }
    end
end
