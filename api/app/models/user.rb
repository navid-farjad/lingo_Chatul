class User < ApplicationRecord
  has_secure_password validations: false
  has_many :user_card_states, dependent: :destroy
  has_many :cards, through: :user_card_states

  TIERS = %w[anonymous free paid].freeze

  validates :device_token, presence: true, uniqueness: true
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :tier, inclusion: { in: TIERS }

  before_validation :ensure_device_token, on: :create

  def anonymous?
    tier == "anonymous"
  end

  def registered?
    !anonymous? && email.present?
  end

  private

  def ensure_device_token
    self.device_token ||= SecureRandom.urlsafe_base64(32)
  end
end
