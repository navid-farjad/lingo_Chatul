module ContentPipeline
  # Calls ElevenLabs TTS to generate native-pronunciation audio for a word.
  # Uses the multilingual_v2 model so a single voice can handle Greek and
  # any other language we add later.
  class AudioGenerator
    # Bella (multilingual stock voice) — clear, friendly, works for Greek.
    DEFAULT_VOICE_ID = "EXAVITQu4vr4xnSDxMaL".freeze
    MODEL = "eleven_multilingual_v2".freeze

    def initialize(api_key: ENV.fetch("ELEVENLABS_API_KEY"), voice_id: DEFAULT_VOICE_ID)
      @api_key = api_key
      @voice_id = voice_id
    end

    # @param text [String]  text to synthesize (the word in its native script)
    # @return [Hash]  { bytes:, content_type:, raw: }
    def call(text:)
      response = connection.post("https://api.elevenlabs.io/v1/text-to-speech/#{@voice_id}") do |req|
        req.headers["xi-api-key"] = @api_key
        req.headers["Content-Type"] = "application/json"
        req.headers["Accept"] = "audio/mpeg"
        req.body = JSON.generate(
          text: text,
          model_id: MODEL,
          voice_settings: { stability: 0.5, similarity_boost: 0.75, style: 0.0 }
        )
      end

      raise "ElevenLabs error: #{response.status} #{response.body[0, 200]}" unless response.success?

      {
        bytes: response.body,
        content_type: "audio/mpeg",
        raw: { model: MODEL, voice_id: @voice_id }
      }
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.adapter Faraday.default_adapter
        f.options.timeout = 60
      end
    end
  end
end
