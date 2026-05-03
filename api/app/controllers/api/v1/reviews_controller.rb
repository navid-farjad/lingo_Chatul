module Api
  module V1
    # POST /api/v1/cards/:card_id/reviews
    # Body: { correct: true|false }
    # Updates the user's Leitner state for this card and returns the new state.
    class ReviewsController < ApplicationController
      def create
        card = Card.find(params[:card_id])
        state = UserCardState.find_or_initialize_by(user: current_user, card: card)
        state.leitner_box ||= 1
        state.correct_count ||= 0
        state.incorrect_count ||= 0
        state.review!(correct: ActiveModel::Type::Boolean.new.cast(params[:correct]))

        render json: {
          card_id: card.id,
          leitner_box: state.leitner_box,
          next_review_at: state.next_review_at,
          correct_count: state.correct_count,
          incorrect_count: state.incorrect_count
        }
      end
    end
  end
end
