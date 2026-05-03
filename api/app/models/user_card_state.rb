class UserCardState < ApplicationRecord
  belongs_to :user
  belongs_to :card

  # Leitner box → days until next review (box 1 = tomorrow, box 5 = 16 days)
  LEITNER_INTERVALS_DAYS = [1, 2, 4, 8, 16].freeze

  RATINGS = %w[again hard good easy].freeze

  validates :user_id, uniqueness: { scope: :card_id }
  validates :leitner_box, numericality: { only_integer: true, in: 1..5 }

  scope :due, ->(at = Time.current) {
    where("next_review_at IS NULL OR next_review_at <= ?", at)
  }

  # Anki-inspired 4-button rating mapped onto our 5-box Leitner system.
  # @param rating [String]  one of: again, hard, good, easy
  def review!(rating:)
    rating = rating.to_s
    raise ArgumentError, "Unknown rating: #{rating}" unless RATINGS.include?(rating)

    case rating
    when "again"
      self.incorrect_count += 1
      self.leitner_box = 1
    when "hard"
      self.correct_count += 1
      # stay in current box
    when "good"
      self.correct_count += 1
      self.leitner_box = [leitner_box + 1, 5].min
    when "easy"
      self.correct_count += 1
      self.leitner_box = [leitner_box + 2, 5].min
    end

    self.last_reviewed_at = Time.current
    self.next_review_at = LEITNER_INTERVALS_DAYS[leitner_box - 1].days.from_now
    save!
  end

  def snapshot
    {
      leitner_box: leitner_box,
      correct_count: correct_count,
      incorrect_count: incorrect_count,
      next_review_at: next_review_at,
      last_reviewed_at: last_reviewed_at
    }
  end
end
