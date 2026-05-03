class Language < ApplicationRecord
  has_many :words, dependent: :destroy

  validates :code, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }
end
