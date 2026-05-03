module Api
  module V1
    class CardsController < ApplicationController
      def index
        cards = Card.ready
          .includes(word: :language)
          .order("languages.code, words.native")

        render json: cards.map { |c| serialize(c) }
      end

      # GET /api/v1/cards/queue
      # Returns today's review queue: cards whose UserCardState is due, plus
      # any cards the user has never seen (capped at `limit`, default 20).
      def queue
        limit = (params[:limit] || 20).to_i.clamp(1, 100)

        # 1. Cards where the user already has state and review is due
        due_states = UserCardState.due.where(user: current_user).limit(limit)
        due_card_ids = due_states.pluck(:card_id)

        # 2. New cards the user hasn't seen yet
        seen_ids = current_user.user_card_states.pluck(:card_id)
        new_cards = Card.ready.where.not(id: seen_ids).limit(limit - due_card_ids.size)

        cards = (Card.where(id: due_card_ids) + new_cards)
          .uniq
          .first(limit)

        # Preload associations to avoid N+1
        ActiveRecord::Associations::Preloader.new(
          records: cards, associations: { word: :language }
        ).call

        render json: cards.map { |c| serialize(c) }
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
