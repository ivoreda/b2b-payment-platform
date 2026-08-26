# Server-to-server API auth. The raw bearer token is generated once at
# creation and exposed only in-memory via #token - only its SHA-256 digest
# is ever persisted, so a database leak doesn't hand out usable credentials.
class ApiCredential < ApplicationRecord
  belongs_to :merchant

  before_validation :generate_token, on: :create

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  class << self
    def authenticate(raw_token)
      return nil if raw_token.blank?

      credential = active.find_by(token_digest: digest_for(raw_token))
      credential&.touch(:last_used_at)
      credential
    end

    def digest_for(raw_token)
      Digest::SHA256.hexdigest(raw_token)
    end
  end

  attr_reader :token

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  private

  def generate_token
    return if token_digest.present?

    raw_token = "sk_#{SecureRandom.hex(24)}"
    @token = raw_token
    self.token_digest = self.class.digest_for(raw_token)
    self.token_last_four = raw_token.last(4)
  end
end
