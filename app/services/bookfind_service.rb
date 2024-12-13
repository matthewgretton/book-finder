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

  def search(query)
    agent = TimeHelper.time_function("Creating Agent...") do
      create_agent
    end

    page = TimeHelper.time_function("Navigate to search...") do
      navigate_to_search(agent)
    end

    # Validate session after navigating to the search page
    validate_session!(agent, page)

    results_page = TimeHelper.time_function("Submit search form...") do
      submit_search_form(agent, page, query)
    end

    TimeHelper.time_function("Parse Results...") do
      parse_results(agent, results_page)
    end
  end

  private

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
    end

    def navigate_to_search(agent)
      agent.get("https://www.arbookfind.co.uk/advanced.aspx")
    end

    def validate_session!(agent, page)
      # Check if the page redirects to the user type selection form or is invalid
      if needs_user_type_selection?(page)
        puts "Session invalid. Reinitializing..."
        setup_initial_cookies(agent)
      end
    end

    def needs_user_type_selection?(page)
      # Check if the page indicates that user type selection is required
      !!page.at_css("input[type='radio'][value='radParent']")
    end

    def submit_search_form(agent, page, query)
      form = page.form_with(name: "aspnetForm")
      form["ctl00$ContentPlaceHolder1$txtTitle"] = query if query.present?
      form.submit(form.button_with(name: "ctl00$ContentPlaceHolder1$btnDoIt"))
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
      series = "N/A"
      published = 0
      isbn = "N/A"
      ar_points = 0.0
      word_count = 0

      Book.new(
        title: title,
        author: author,
        series: series.presence,
        published: published,
        isbn: isbn,
        atos_book_level: atos_book_level,
        ar_points: ar_points,
        interest_level: interest_level,
        word_count: word_count
      )
    end
end
