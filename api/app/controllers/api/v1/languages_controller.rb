module Api
  module V1
    # Lists languages that have at least one ready card. Used by the frontend
    # to populate the language switcher.
    class LanguagesController < ApplicationController
      def index
        languages = Language.enabled
          .joins(words: :card)
          .where.not(cards: { image_url: nil, audio_url: nil })
          .distinct
          .order(:name)

        render json: languages.map { |l|
          {
            code: l.code,
            name: l.name,
            rtl: rtl?(l.code),
            card_count: l.words.joins(:card).where.not(cards: { image_url: nil, audio_url: nil }).count
          }
        }
      end

      private

      RTL_CODES = %w[he ar fa ur].freeze

      def rtl?(code)
        RTL_CODES.include?(code)
      end
    end
  end
end
