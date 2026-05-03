module ContentPipeline
  # Calls Fal AI nano-banana (Google Gemini 2.5 Flash Image) to generate a
  # photorealistic cat-themed mnemonic image. Returns a hash with the binary
  # image content and metadata.
  class ImageGenerator
    API_URL = "https://fal.run/fal-ai/nano-banana".freeze

    def initialize(api_key: ENV.fetch("FAL_KEY"))
      @api_key = api_key
    end

    # @param prompt [String]  image-generation prompt produced by StoryGenerator
    # @return [Hash]  { bytes:, content_type:, raw: }
    def call(prompt:)
      response = connection.post(API_URL) do |req|
        req.headers["Authorization"] = "Key #{@api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.generate(
          prompt: prompt,
          num_images: 1,
          output_format: "jpeg"
        )
      end

      raise "Fal AI error: #{response.status} #{response.body}" unless response.success?

      body = JSON.parse(response.body)
      image_url = body.dig("images", 0, "url") ||
        raise("No image URL in Fal response: #{body}")

      bytes = download(image_url)

      {
        bytes: bytes,
        content_type: "image/jpeg",
        raw: { model: "fal-ai/nano-banana", source_url: image_url }
      }
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.adapter Faraday.default_adapter
        f.options.timeout = 120
      end
    end

    def download(url)
      resp = Faraday.get(url)
      raise "Failed to download image: #{resp.status}" unless resp.success?
      resp.body
    end
  end
end
