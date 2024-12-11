class BooksController < ApplicationController
  def search
    @books = []

    if params[:query].present?
      start_time = Time.now
      @books = search_arbookfind(params[:query])
      end_time = Time.now
      elapsed_time = end_time - start_time
      puts "Elapsed time: #{elapsed_time} seconds"
    elsif params[:photos].present?
      photos = params[:photos].reject(&:blank?)
      isbns = photos.map { |photo| IsbnExtractor.extract(photo) }.uniq
      puts "Extracted ISBNs: #{isbns}"
      isbns.each { |isbn| @books.concat(search_arbookfind(isbn)) }
    end

    render :search
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
      page = agent.get("https://www.arbookfind.co.uk/default.aspx")
      form = page.form_with(name: "form1")
      radio_button = form.radiobutton_with(value: "radParent")
      radio_button.check
      page = form.submit(form.button_with(name: "btnSubmitUserType"))
      page
    end

    def submit_search_form(page, query)
      form = page.form_with(name: "aspnetForm")
      form["ctl00$ContentPlaceHolder1$txtKeyWords"] = query if query.present?
      results_page = form.submit(form.button_with(name: "ctl00$ContentPlaceHolder1$btnDoIt"))
      results_page
    end

    def search_arbookfind(query)
      begin
        agent = Mechanize.new
        page = navigate_to_search(agent)
        results_page = submit_search_form(page, query)
        doc = Nokogiri::HTML(results_page.body)
        book_details = doc.css("td.book-detail")
        books = []
        book_details.each do |book_detail|
          books << extract_book_from_details(agent, book_detail)
        end
        books.presence || []
      rescue => e
        Rails.logger.error "Error in search_arbookfind: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        []
      end
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
      detail_link = book_detail.at_css("a#book-title")["href"]
      detail_page_url = "https://www.arbookfind.co.uk/#{detail_link}"
      detail_page = agent.get(detail_page_url)
      detail_doc = Nokogiri::HTML(detail_page.body)
      series_elements = detail_doc.css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblSeriesLabel")
      series = series_elements.map { |element| element.text.strip.chomp(";") }.join(", ")
      ar_points_element = detail_doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblPoints")
      ar_points = ar_points_element ? ar_points_element.text.strip.to_f : 0.0
      word_count_element = detail_doc.at_css("span#ctl00_ContentPlaceHolder1_ucBookDetail_lblWordCount")
      word_count = word_count_element ? word_count_element.text.strip.to_i : 0
      details_table = detail_doc.at_css("table#ctl00_ContentPlaceHolder1_ucBookDetail_tblPublisherTable")
      if details_table
        first_row = details_table.css("tr")[1]
        if first_row
          isbn = first_row.at_css("td:nth-child(2)").text.strip
          published = first_row.at_css("td:nth-child(3)").text.strip.to_i
        end
      end
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
