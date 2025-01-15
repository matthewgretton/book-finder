class BookfindService
  FORM_FIELDS = {
    search_term: "ctl00$ContentPlaceHolder1$txtKeyWords",
    submit: "ctl00$ContentPlaceHolder1$btnDoIt"
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
    setup_session
  end

  def search(query)
    perform_search(query)
  end

  def search_by_isbn(isbn)
    result = find_book_by_isbn(isbn)
    return [] if result.nil?

    title = result[:title]
    perform_search(title)
  end

  private

    def setup_session
      Rails.logger.info "Setting up AR Bookfind session"
      agent = Mechanize.new
      page = agent.get("https://www.arbookfind.co.uk/default.aspx")

      if form = page.form_with(name: "form1")
        radio = form.radiobutton_with(value: "radParent")
        if radio
          radio.check
          page = form.submit(form.button_with(name: "btnSubmitUserType"))
        end
      end

      @search_page = page
      @agent = agent
    end

    def perform_search(search_term)
      begin
        form = @search_page.form_with(name: "aspnetForm")

        if form
          form[FORM_FIELDS[:search_term]] = search_term

          submit_button = form.button_with(name: FORM_FIELDS[:submit])
          if submit_button
            results_page = form.submit(submit_button)
            parse_results(results_page)
          else
            []
          end
        else
          []
        end
      rescue OpenSSL::SSL::SSLError, Mechanize::Error, Net::HTTP::Persistent::Error
        @agent = nil
        @search_page = nil
        setup_session
        retry
      end
    end

    def parse_results(page)
      doc = Nokogiri::HTML(page.body)

      no_results = doc.at_css("span#ctl00_ContentPlaceHolder1_lblNoResults")
      return [] if no_results && no_results.text.strip.present?

      book_details = doc.css("table.book-result")
      book_details.map { |detail| extract_book_from_details(detail) }.compact
    end

    def extract_book_from_details(book_detail)
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
        detail_page = @agent.get(detail_page_url)
        detail_doc = Nokogiri::HTML(detail_page.body)

        series = extract_series(detail_doc)
        word_count = extract_word_count(detail_doc)
        other_details = extract_other_details(meta_paragraph)

        BookDetails.new(
          title: title,
          author: author,
          series: series,
          atos_book_level: other_details[:atos_book_level],
          interest_level: other_details[:interest_level],
          ar_points: other_details[:ar_points],
          word_count: word_count
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
