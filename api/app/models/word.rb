class Word < ApplicationRecord
  belongs_to :language
  has_one :card, dependent: :destroy

  validates :native, presence: true, uniqueness: { scope: :language_id }
  validates :english, presence: true
end
