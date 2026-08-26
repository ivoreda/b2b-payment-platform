# Gives a model an opaque, non-sequential public identifier (e.g. "ord_a1b2c3...")
# so IDs used in URLs/JSON never leak sequential database ids or order-of-creation.
module HasReference
  extend ActiveSupport::Concern

  class_methods do
    def reference_prefix(prefix)
      @reference_prefix = prefix
    end

    def _reference_prefix
      @reference_prefix
    end
  end

  included do
    before_validation :assign_reference, on: :create
    validates :reference, presence: true, uniqueness: true
  end

  private

  def assign_reference
    self.reference ||= "#{self.class._reference_prefix}_#{SecureRandom.hex(12)}"
  end
end
