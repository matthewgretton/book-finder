module BookRationalisationService
  def self.sort_results(query, results)
    system_prompt = <<~PROMPT
      You are an app for seaching children's books:

      Input:
      search_query (a string descirbing a title, author, or series)
      search_results (an array of objects with keys "title" and "author") this is the result of running the query against the openlibrary API

      You will:
      - Based on the search_results generate all full unique book titles, with associated authors.
      - Order by published date, so books in a series appear in the correct order.
      - Use UK titles for books, and don't return separate items where differences between uk and us titles for same book for example.

      Return only a JSON array of objects with the keys "title" and "author", with no extra commentary.
    PROMPT

    system_prompt2 = <<~PROMPT
      You will be passed a search_query string, signifying what the user is looking for, and you will be passed a list of book objects with  title and author fields, first_published date (search_results)

      Please re-order these books in terms of published date, and add any missing books. There is the possiblity of dodgey data so#{' '}
      please check for this.

      Return only a JSON array of objects with the keys "title" and "author", with no extra commentary.
  PROMPT

    user_prompt = <<~PROMPT
      search_query: #{query}
      search_results: #{results}
    PROMPT

    begin
      ordered_response = Gpt4oMini.call(
        system_prompt: system_prompt2,
        user_prompt: user_prompt,
        temperature: 0.1
      )
      # Remove any markdown code fences that might be wrapping the JSON.
      cleaned_response = ordered_response
                         .gsub(/\A```(?:json)?\s*/, "")
                         .gsub(/```\s*\z/, "")
                         .strip
      JSON.parse(cleaned_response, symbolize_names: true)
    rescue StandardError => e
      Rails.logger.error "LLM ordering failed: #{e.message}"
      # In case of error, fall back to the raw results.
      results
    end
  end
end
