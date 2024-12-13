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

  COOKIE_FILE = Rails.root.join("tmp", "arbookfind_cookies.yml")

  # Singleton instance variables for caching
  @cached_page = nil
  @last_cached_at = nil

  CACHE_EXPIRY_TIME = 10.minutes

  class << self
    attr_accessor :cached_page, :last_cached_at

    def reset_cache(agent)
      puts "Reloading pristine page for caching..."
      self.cached_page = agent.get("https://www.arbookfind.co.uk/advanced.aspx")
      self.last_cached_at = Time.now
    end

    def cache_expired?
      last_cached_at.nil? || Time.now - last_cached_at > CACHE_EXPIRY_TIME
    end
  end

  def search_by_title(title)
    search_params = { title: title }
    perform_search(search_params)
  end

  def search_by_isbn(isbn)
    search_params = { isbn: isbn }
    perform_search(search_params)
  end

  private

    def perform_search(search_params)
      agent = create_agent

      # Reload the cache if it is expired
      if self.class.cached_page.nil? || self.class.cache_expired?
        self.class.reset_cache(agent)
      end

      # Use a fresh clone of the cached page to avoid persisting form state
      pristine_page = self.class.cached_page.dup

      results_page = submit_search_form(agent, pristine_page, search_params)

      parse_results(agent, results_page)
    end

    def create_agent
      agent = Mechanize.new
      if File.exist?(COOKIE_FILE)
        puts "Loading cookies from #{COOKIE_FILE}"
        agent.cookie_jar.load(COOKIE_FILE.to_s)
      else
        puts "Setting up initial cookies"
        setup_initial_cookies(agent)
      end
      agent
    end

    def setup_initial_cookies(agent)
      page = agent.get("https://www.arbookfind.co.uk/advanced.aspx")
      form = page.form_with(name: "form1")
      form.radiobutton_with(value: "radParent").check
      form.submit(form.button_with(name: "btnSubmitUserType"))
      agent.cookie_jar.save_as(COOKIE_FILE.to_s)

      # Cache the pristine page after navigating to advanced.aspx
      self.class.cached_page = agent.get("https://www.arbookfind.co.uk/advanced.aspx")
      self.class.last_cached_at = Time.now
    end

    def submit_search_form(agent, page, search_params)
      form = page.form_with(name: "aspnetForm")

      # Set the new search parameters
      search_params.each do |param, value|
        field = FORM_FIELDS[param]
        form[field] = value if field && value.present?
      end

      form.submit(form.button_with(name: FORM_FIELDS[:submit]))
    end

    def parse_results(agent, page)
      doc = Nokogiri::HTML(page.body)
      book_details = doc.css("td.book-detail")
      book_details.map { |detail| extract_book_from_details(agent, detail) }
    end

    def extract_book_from_details(agent, book_detail)
      title = book_detail.at_css("a#book-title").text.strip
      author = book_detail.at_css("p").text.strip.split("\n").first.strip
      bl_text = book_detail.at_css("p").text.match(/BL: (\d+\.\d+)/)
      atos_book_level = bl_text ? bl_text[1].to_f : 0.0
      interest_level_match = book_detail.at_css("p").text.match(/IL: (\w+)/)
      interest_level = interest_level_match ? interest_level_match[1] : "Unknown"

      Book.new(
        title: title,
        author: author,
        atos_book_level: atos_book_level,
        interest_level: interest_level
      )
    end
end
