require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with a merchant, email, and password" do
    user = build(:user)

    expect(user).to be_valid
  end

  it "requires an email" do
    user = build(:user, email: nil)

    expect(user).not_to be_valid
  end

  it "requires a well-formed email" do
    user = build(:user, email: "not-an-email")

    expect(user).not_to be_valid
  end

  it "requires a unique email, case-insensitively" do
    create(:user, email: "merchant@example.com")
    duplicate = build(:user, email: "Merchant@Example.com")

    expect(duplicate).not_to be_valid
  end

  it "normalizes email to a stripped, downcased form" do
    user = create(:user, email: "  Merchant@Example.com  ")

    expect(user.email).to eq("merchant@example.com")
  end

  it "requires a password of at least 8 characters" do
    user = build(:user, password: "short")

    expect(user).not_to be_valid
  end

  it "requires a password on create" do
    user = build(:user, password: nil)

    expect(user).not_to be_valid
  end

  it "authenticates with the correct password" do
    user = create(:user, password: "password123")

    expect(user.authenticate("password123")).to eq(user)
  end

  it "does not authenticate with an incorrect password" do
    user = create(:user, password: "password123")

    expect(user.authenticate("wrong-password")).to be false
  end

  it "defaults to member role" do
    user = User.new

    expect(user).to be_member
  end
end
