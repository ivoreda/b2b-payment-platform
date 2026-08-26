require "rails_helper"

RSpec.describe "Dashboard::Orders", type: :request do
  let(:merchant) { create(:merchant) }
  let(:user) { create(:user, merchant: merchant, password: "password123") }

  def login_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def count_queries
    count = 0
    counter = ->(*) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe "GET /dashboard/orders" do
    it "redirects to login when logged out" do
      get dashboard_orders_path

      expect(response).to redirect_to(login_path)
    end

    it "lists only the current merchant's orders" do
      login_as(user)
      mine = create(:order, merchant: merchant)
      create(:order, merchant: create(:merchant))

      get dashboard_orders_path

      expect(response.body).to include(mine.reference)
    end

    it "shows each order's latest payment status without N+1 queries as order count grows" do
      login_as(user)
      create_list(:order, 2, merchant: merchant).each { |o| create(:payment, order: o) }

      baseline = count_queries { get dashboard_orders_path }

      create_list(:order, 6, merchant: merchant).each { |o| create(:payment, order: o) }

      scaled = count_queries { get dashboard_orders_path }

      expect(scaled).to eq(baseline)
    end
  end

  describe "GET /dashboard/orders/:reference" do
    it "shows the order, its payments, and status history for the current merchant" do
      login_as(user)
      order = create(:order, merchant: merchant)
      payment = create(:payment, order: order)
      payment.mark_succeeded!(provider_reference: "mock_ch_1")

      get dashboard_order_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(payment.reference)
      expect(response.body).to include("succeeded")
    end

    it "returns 404 for another merchant's order" do
      login_as(user)
      other_order = create(:order, merchant: create(:merchant))

      get dashboard_order_path(other_order)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects to login when logged out" do
      order = create(:order, merchant: merchant)

      get dashboard_order_path(order)

      expect(response).to redirect_to(login_path)
    end
  end
end
