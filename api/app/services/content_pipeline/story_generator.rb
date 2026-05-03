module ContentPipeline
  # Calls Anthropic Claude to produce both a vivid mnemonic story AND an
  # image-generation prompt for Fal AI in a single call. Returns a hash
  # with :story and :image_prompt keys.
  class StoryGenerator
    API_URL = "https://api.anthropic.com/v1/messages".freeze
    MODEL = "claude-sonnet-4-6".freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You write mnemonic learning aids for a language-learning app called lingo_Chatul.
      Every card features a CAT doing something memorable.

      For each word, return STRICT JSON with two fields:
      - "story": a 1-2 sentence vivid mnemonic in English. Anchor the foreign-word's
        SOUND to its meaning using a creative cat scene. Capitalize the syllable
        from the word that the imagery is hooking into. Be funny, surprising, or
        weird — boring stories don't stick.
      - "image_prompt": a detailed prompt for a photorealistic image generator
        depicting that exact scene. The cat must be central. ALWAYS include the
        words "photorealistic, professional photography, hyperrealistic, natural
        lighting, 4k, sharp focus" at the end. Do not request any text/captions
        in the image.

      Return ONLY the JSON object, no preamble, no markdown fences.
    PROMPT

    def initialize(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      @api_key = api_key
    end

    # @param native [String]  word in target language ("καλημέρα")
    # @param romanization [String]  ("kalimera")
    # @param english [String]  ("good morning")
    # @return [Hash]  { story:, image_prompt:, raw: }
    def call(native:, romanization:, english:, language_name: "Greek", notes: nil)
      user_msg = <<~MSG
        Language: #{language_name}
        Word: #{native} (romanized: #{romanization})
        Meaning: #{english}
        #{notes.present? ? "Notes: #{notes}" : ""}

        Write the mnemonic JSON now.
      MSG

      response = connection.post(API_URL) do |req|
        req.headers["x-api-key"] = @api_key
        req.headers["anthropic-version"] = "2023-06-01"
        req.headers["content-type"] = "application/json"
        req.body = JSON.generate(
          model: MODEL,
          max_tokens: 800,
          system: SYSTEM_PROMPT,
          messages: [{ role: "user", content: user_msg }]
        )
      end

      raise "Claude API error: #{response.status} #{response.body}" unless response.success?

      body = JSON.parse(response.body)
      text = body.dig("content", 0, "text") || raise("No text in Claude response: #{body}")

      parsed = JSON.parse(extract_json(text))
      {
        story: parsed.fetch("story"),
        image_prompt: parsed.fetch("image_prompt"),
        raw: { model: MODEL, usage: body["usage"] }
      }
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.adapter Faraday.default_adapter
        f.options.timeout = 60
      end
    end

    def extract_json(text)
      # Claude usually returns clean JSON, but strip code fences just in case.
      text.strip.sub(/\A```(?:json)?\s*/, "").sub(/```\z/, "")
    end
  end
end
