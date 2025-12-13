module Gpt4oMini
  API_ENDPOINT = "https://api.openai.com/v1/chat/completions"
  API_KEY = Rails.application.credentials.gpt4omini_api_key

  # Call the API by providing both a system prompt and a user prompt.
  # Optional parameters (e.g., temperature, top_p, etc.) can be passed in via optional_params.
  def self.call(system_prompt:, user_prompt:, **optional_params)
    headers = {
      "Authorization" => "Bearer #{API_KEY}",
      "Content-Type"  => "application/json"
    }

    body = {
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    }.merge(optional_params)

    response = HTTParty.post(API_ENDPOINT, headers: headers, body: body.to_json)

    if response.code == 200
      JSON.parse(response.body)["choices"][0]["message"]["content"]
    else
      raise "Error calling GPT-4o-mini: #{response.body}"
    end
  end
end
