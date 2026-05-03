module Api
  module V1
    # POST   /api/v1/cards/:card_id/reviews   body: { rating: again|hard|good|easy }
    # DELETE /api/v1/cards/:card_id/reviews   body: { prior_state: {...} }  -- undo
    class ReviewsController < ApplicationController
      def create
        card = Card.find(params[:card_id])
        state = UserCardState.find_or_initialize_by(user: current_user, card: card)
        state.leitner_box ||= 1
        state.correct_count ||= 0
        state.incorrect_count ||= 0

        rating = params[:rating].presence || derive_rating_from_correct(params[:correct])
        prior_state = state.persisted? ? state.snapshot : nil

        state.review!(rating: rating)

        render json: state_payload(card, state).merge(prior_state: prior_state)
      end

      # POST /api/v1/cards/:card_id/reviews/undo  body: { prior_state: {...} | null }
      # Restore the user's state for this card to a prior snapshot.
      # If prior_state is null, destroy the record (it didn't exist before the review).
      def undo
        card = Card.find(params[:card_id])
        state = UserCardState.find_by(user: current_user, card: card)
        return render(json: { ok: true }) unless state

        prior = params[:prior_state]
        if prior.blank? || prior == "null"
          state.destroy!
        else
          state.update!(
            leitner_box: prior[:leitner_box] || prior["leitner_box"],
            correct_count: prior[:correct_count] || prior["correct_count"],
            incorrect_count: prior[:incorrect_count] || prior["incorrect_count"],
            next_review_at: prior[:next_review_at] || prior["next_review_at"],
            last_reviewed_at: prior[:last_reviewed_at] || prior["last_reviewed_at"]
          )
        end

        render json: { ok: true }
      end

      private

      def derive_rating_from_correct(correct_param)
        # Backwards compat for the old { correct: true|false } API
        ActiveModel::Type::Boolean.new.cast(correct_param) ? "good" : "again"
      end

      def state_payload(card, state)
        {
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
