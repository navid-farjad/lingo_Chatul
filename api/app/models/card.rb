class Card < ApplicationRecord
  belongs_to :word
  has_one :language, through: :word
  has_many :user_card_states, dependent: :destroy

  scope :ready, -> { where.not(image_url: nil).where.not(audio_url: nil).where.not(story_text: nil) }
end
