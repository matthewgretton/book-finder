class BooksController < ApplicationController
  # GET /books or /books.json
  def index
    @books = Book.all
  end

  def search
    if params[:query].present?

      start_time = Time.now

      @books = search_arbookfind(params[:query])

      end_time = Time.now

      elapsed_time = end_time - start_time

      puts "Elapsed time: #{elapsed_time} seconds"

    else
      @books = []
    end
  end

  def search_by_isbns
    photos = params[:photos].reject(&:blank?)

    # Debug: Save first uploaded file for inspection
    if photos.any?
      first_photo = photos.first
      debug_path = Rails.root.join("tmp", "debug_#{Time.now.to_i}_#{first_photo.original_filename}")
      FileUtils.cp(first_photo.tempfile.path, debug_path)
      Rails.logger.info "Debug: Saved uploaded file to #{debug_path}"
    end

    isbns = photos.map do |photo|
      IsbnExtractor.extract(photo)
    end.uniq

    respond_to do |format|
      format.html { redirect_to search_books_path(query: isbns.join(" ")) }
      format.json { render json: { isbns: isbns } }
    end
  end

    private

      # Only allow a list of trusted parameters through.
      def book_params
        params.require(:book).permit(:title, :author, :atos_book_level, :ar_points, :interest_level, :word_count)
      end

      def parse_boolean_param(param)
        param == "true"
      end

      def navigate_to_search(agent)
        # Get the search page
        page = agent.get("https://www.arbookfind.co.uk/default.aspx")
        # page = agent.get("https://www.arbookfind.co.uk/advanced.aspx")
        # Check if the user type form is present
        form = page.form_with(name: "form1")

        # Select the user type form and submit it
        radio_button = form.radiobutton_with(value: "radParent")
        radio_button.check

        # Submit the form to navigate to the advanced search page
        page = form.submit(form.button_with(name: "btnSubmitUserType"))

        page
      end

      def submit_search_form(page, query)
        # Select the quick search form and submit the search query
        form = page.form_with(name: "aspnetForm")
        form["ctl00$ContentPlaceHolder1$txtKeyWords"] = query if query.present?
        # form["ctl00$ContentPlaceHolder1$txtTitle"] = query if query.present?

        results_page = form.submit(form.button_with(name: "ctl00$ContentPlaceHolder1$btnDoIt"))

        results_page
      end

      def extract_book_from_details(agent, book_detail)
        # Extract the title, author, and ATOS/BL level directly from the search results
        title = book_detail.at_css("a#book-title").text.strip
        author = book_detail.at_css("p").text.strip.split("\n").first.strip
        bl_text = book_detail.at_css("p").text.match(/BL: (\d+\.\d+)/)
        atos_book_level = bl_text ? bl_text[1].to_f : 0.0
        interest_level_match = book_detail.at_css("p").text.match(/IL: (\w+)/)
        interest_level = interest_level_match ? interest_level_to_age_range(interest_level_match[1]) : "Unknown"

        # Placeholder values for non-nullable fields
        series = "N/A"
        published = 0
        isbn = "N/A"
        ar_points = 0.0
        word_count = 0

        detail_link = book_detail.at_css("a#book-title")["href"]
        detail_page_url = "https://www.arbookfind.co.uk/#{detail_link}"
        detail_page = agent.get(detail_page_url)
        detail_doc = Nokogiri::HTML(detail_page.body)

        # Extract additional information from the detailed page
        series_elements = detail_doc.css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblSeriesLabel")
        series = series_elements.map { |element| element.text.strip.chomp(";") }.join(", ")
        ar_points_element = detail_doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblPoints")
        ar_points = ar_points_element ? ar_points_element.text.strip.to_f : 0.0
        word_count_element = detail_doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblWordCount")
        word_count = word_count_element ? word_count_element.text.strip.to_i : 0

        details_table = detail_doc.at_css("table#ctl00_ContentPlaceHolder1_ucBookDetail_tblPublisherTable")
        if details_table
          first_row = details_table.css("tr")[1] # Get the first data row (second row in the table)
          if first_row
            isbn = first_row.at_css("td:nth-child(2)").text.strip
            published = first_row.at_css("td:nth-child(3)").text.strip.to_i
          end
        end

        # Create a new Book instance and add it to the books array
        Book.new(
          title: title,
          author: author,
          series: series.presence, # Ensure series can be nil
          published: published,
          isbn: isbn,
          atos_book_level: atos_book_level,
          ar_points: ar_points,
          interest_level: interest_level,
          word_count: word_count
        )
      end

      # Method to search AR Bookfind and extract book details
      def search_arbookfind(query)
        # Initialize Mechanize agent
        agent = Mechanize.new

        # Get the search page and navigate to the advanced search form
        page = navigate_to_search(agent)

        results_page = submit_search_form(page, query)

        # Parse the search results
        doc = Nokogiri::HTML(results_page.body)

        # Select all book detail parent elements
        book_details = doc.css("td.book-detail")

        # Initialize an empty array to store the book details
        books =  []

        # Iterate over each book detail parent element
        book_details.each do |book_detail|
          books << extract_book_from_details(agent, book_detail)
        end

        books
      end

      def interest_level_to_age_range(interest_level)
        case interest_level
        when "LY"
          "5y-8y"
        when "MY"
          "9y-13y"
        when "MY+"
          "12y+"
        when "UY"
          "14y+"
        else
          "Unknown"
        end
      end
end
