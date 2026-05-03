class User < ApplicationRecord
  has_secure_password validations: false
  has_many :user_card_states, dependent: :destroy
  has_many :cards, through: :user_card_states

  TIERS = %w[anonymous free paid].freeze

  validates :device_token, presence: true, uniqueness: true
  validates :email,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP },
    allow_nil: true
  validates :tier, inclusion: { in: TIERS }
  validates :password, length: { minimum: 8 }, allow_blank: true

  before_validation :ensure_device_token, on: :create
  before_save :downcase_email

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

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
