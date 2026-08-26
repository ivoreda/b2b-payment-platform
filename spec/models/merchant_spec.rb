require "rails_helper"

RSpec.describe Merchant, type: :model do
  it "is valid with a name" do
    merchant = build(:merchant)

    expect(merchant).to be_valid
  end

  it "requires a name" do
    merchant = build(:merchant, name: nil)

    expect(merchant).not_to be_valid
  end

  it "defaults to active status" do
    merchant = Merchant.new(name: "Acme")

    expect(merchant).to be_active
  end

  it "destroys its users when destroyed" do
    merchant = create(:merchant)
    create(:user, merchant: merchant)

    expect { merchant.destroy }.to change(User, :count).by(-1)
  end
end
