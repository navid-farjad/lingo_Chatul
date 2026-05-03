class UserCardState < ApplicationRecord
  belongs_to :user
  belongs_to :card

  # Leitner box → days until next review (box 1 = tomorrow, box 5 = 16 days)
  LEITNER_INTERVALS_DAYS = [1, 2, 4, 8, 16].freeze

  validates :user_id, uniqueness: { scope: :card_id }
  validates :leitner_box, numericality: { only_integer: true, in: 1..5 }

  scope :due, ->(at = Time.current) {
    where("next_review_at IS NULL OR next_review_at <= ?", at)
  }

  def review!(correct:)
    if correct
      self.correct_count += 1
      self.leitner_box = [leitner_box + 1, 5].min
    else
      self.incorrect_count += 1
      self.leitner_box = 1
    end
    self.last_reviewed_at = Time.current
    self.next_review_at = LEITNER_INTERVALS_DAYS[leitner_box - 1].days.from_now
    save!
  end
end
