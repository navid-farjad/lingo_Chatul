module Api
  module V1
    class CardsController < ApplicationController
      def index
        cards = Card.ready
          .includes(word: :language)
          .order("languages.code, words.native")

        render json: cards.map { |c| serialize(c) }
      end

      # GET /api/v1/cards/queue?language=el&limit=20
      # Returns today's review queue: cards whose UserCardState is due, plus
      # any cards the user has never seen, scoped to a single language.
      def queue
        limit = (params[:limit] || 20).to_i.clamp(1, 100)
        language_code = (params[:language] || "el").to_s
        language = Language.enabled.find_by(code: language_code)
        return render(json: []) unless language

        word_ids = language.words.pluck(:id)

        due_states = UserCardState.due
          .where(user: current_user)
          .joins(:card)
          .where(cards: { word_id: word_ids })
          .limit(limit)
        due_card_ids = due_states.pluck(:card_id)

        seen_ids = current_user.user_card_states.pluck(:card_id)
        new_cards = Card.ready
          .where(word_id: word_ids)
          .where.not(id: seen_ids)
          .limit(limit - due_card_ids.size)

        cards = (Card.where(id: due_card_ids) + new_cards).uniq.first(limit)

        ActiveRecord::Associations::Preloader.new(
          records: cards, associations: { word: :language }
        ).call

        seen_set = seen_ids.to_set
        render json: cards.map { |c| serialize(c).merge(is_new: !seen_set.include?(c.id)) }
      end

      private

      def serialize(card)
        word = card.word
        {
          id: card.id,
          native: word.native,
          romanization: word.romanization,
          english: word.english,
          part_of_speech: word.part_of_speech,
          language_code: word.language.code,
          language_name: word.language.name,
          story: card.story_text,
          image_url: card.image_url,
          audio_url: card.audio_url
        }
      end
    end
  end
end
