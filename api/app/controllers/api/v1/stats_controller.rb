module Api
  module V1
    # GET /api/v1/stats?language=el
    # Returns the user's progress for one language: Leitner box distribution,
    # totals, today's review count, and consecutive-day streak.
    class StatsController < ApplicationController
      def show
        language_code = (params[:language] || "el").to_s
        language = Language.enabled.find_by(code: language_code)
        return render(json: { error: "Unknown language" }, status: 404) unless language

        card_ids = Card.ready
          .joins(:word)
          .where(words: { language_id: language.id })
          .pluck(:id)

        user_states = current_user.user_card_states.where(card_id: card_ids)

        box_distribution = (1..5).map { |b| [b, user_states.where(leitner_box: b).count] }.to_h

        total_cards = card_ids.size
        cards_started = user_states.count
        cards_mastered = user_states.where("leitner_box >= ?", 5).count
        due_now = user_states.due.count
        reviewed_today = user_states
          .where("last_reviewed_at >= ?", Time.current.beginning_of_day)
          .count

        render json: {
          language: { code: language.code, name: language.name, rtl: rtl?(language.code) },
          box_distribution: box_distribution,
          total_cards: total_cards,
          cards_started: cards_started,
          cards_new: total_cards - cards_started,
          cards_mastered: cards_mastered,
          due_now: due_now,
          reviewed_today: reviewed_today,
          streak_days: compute_streak
        }
      end

      private

      RTL_CODES = %w[he ar fa ur].freeze
      def rtl?(code) = RTL_CODES.include?(code)

      # Streak across all languages: consecutive days ending at today or yesterday
      # where the user reviewed at least one card.
      def compute_streak
        review_dates = current_user.user_card_states
          .where.not(last_reviewed_at: nil)
          .pluck(Arel.sql("DATE(last_reviewed_at)"))
          .map { |d| d.is_a?(String) ? Date.parse(d) : d }
          .to_set

        return 0 if review_dates.empty?

        today = Date.current
        start = if review_dates.include?(today)
                  today
                elsif review_dates.include?(today - 1)
                  today - 1
                end
        return 0 unless start

        streak = 0
        d = start
        while review_dates.include?(d)
          streak += 1
          d -= 1
        end
        streak
      end
    end
  end
end
