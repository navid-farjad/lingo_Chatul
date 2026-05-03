require "csv"

module ContentPipeline
  # Reads a deck CSV from content-pipeline/seeds/, ensures the Language
  # and Word records exist, and runs the AI pipeline for each Word that
  # doesn't already have a complete Card. Idempotent — safe to re-run.
  class Orchestrator
    SEEDS_ROOT = Rails.root.join("..", "content-pipeline", "seeds").freeze

    LANGUAGE_BY_CODE = {
      "el" => { name: "Greek" },
      "es" => { name: "Spanish" },
      "fr" => { name: "French" },
      "it" => { name: "Italian" },
      "de" => { name: "German" },
      "pt" => { name: "Portuguese" },
      "nl" => { name: "Dutch" },
      "tr" => { name: "Turkish" },
      "pl" => { name: "Polish" },
      "ja" => { name: "Japanese" },
      "ko" => { name: "Korean" },
      "zh" => { name: "Chinese" },
      "ar" => { name: "Arabic" },
      "he" => { name: "Hebrew" },
      "ru" => { name: "Russian" }
    }.freeze

    def initialize(deck_name)
      @deck_name = deck_name
      @csv_path = SEEDS_ROOT.join("#{deck_name}.csv")
      raise "Deck not found: #{@csv_path}" unless File.exist?(@csv_path)

      @language_code = detect_language_code(deck_name)
      @story_gen = StoryGenerator.new
      @image_gen = ImageGenerator.new
      @audio_gen = AudioGenerator.new
      @uploader = R2Uploader.new
    end

    def run
      language = upsert_language
      rows = CSV.read(@csv_path, headers: true)

      Rails.logger.info "Generating #{rows.size} cards for #{language.name} (#{language.code})"

      rows.each_with_index do |row, idx|
        word = upsert_word(language, row)
        if word.card&.image_url.present? && word.card&.audio_url.present?
          Rails.logger.info "[#{idx + 1}/#{rows.size}] skip #{word.native} (already complete)"
          next
        end

        Rails.logger.info "[#{idx + 1}/#{rows.size}] generating #{word.native} (#{row['english']})"
        generate_card(word)
      end

      Rails.logger.info "Done."
    end

    private

    def detect_language_code(deck_name)
      # "greek_starter" -> "el", "spanish_a1" -> "es", etc.
      prefix = deck_name.split("_").first
      {
        "greek" => "el",
        "spanish" => "es",
        "french" => "fr",
        "italian" => "it",
        "german" => "de",
        "portuguese" => "pt",
        "dutch" => "nl",
        "turkish" => "tr",
        "polish" => "pl",
        "japanese" => "ja",
        "korean" => "ko",
        "chinese" => "zh",
        "arabic" => "ar",
        "hebrew" => "he",
        "russian" => "ru"
      }.fetch(prefix) { raise "Unknown language for deck: #{deck_name}" }
    end

    def upsert_language
      info = LANGUAGE_BY_CODE.fetch(@language_code)
      Language.find_or_create_by!(code: @language_code) do |l|
        l.name = info[:name]
        l.enabled = true
      end
    end

    def upsert_word(language, row)
      native = row["native"] or raise "CSV row missing 'native' column: #{row.to_h.inspect}"
      Word.find_or_create_by!(language: language, native: native) do |w|
        w.romanization = row["romanization"]
        w.english = row["english"]
        w.part_of_speech = row["part_of_speech"]
        w.notes = row["notes"]
      end
    end

    def generate_card(word)
      card = word.card || word.build_card

      story_result = @story_gen.call(
        native: word.native,
        romanization: word.romanization,
        english: word.english,
        language_name: word.language.name,
        notes: word.notes
      )

      image_result = @image_gen.call(prompt: story_result[:image_prompt])
      audio_result = @audio_gen.call(text: word.native)

      slug = romanization_or_id(word)
      image_url = @uploader.upload(
        key: "images/#{word.language.code}/#{slug}.jpg",
        bytes: image_result[:bytes],
        content_type: image_result[:content_type]
      )
      audio_url = @uploader.upload(
        key: "audio/#{word.language.code}/#{slug}.mp3",
        bytes: audio_result[:bytes],
        content_type: audio_result[:content_type]
      )

      card.assign_attributes(
        story_text: story_result[:story],
        image_url: image_url,
        audio_url: audio_url,
        generation_metadata: {
          image_prompt: story_result[:image_prompt],
          story: story_result[:raw],
          image: image_result[:raw],
          audio: audio_result[:raw]
        },
        generated_at: Time.current
      )
      card.save!
    end

    def romanization_or_id(word)
      (word.romanization.presence || "word_#{word.id}").parameterize
    end
  end
end
