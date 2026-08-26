module ApplicationHelper
  def status_badge(status)
    tag.span(status.humanize, class: "status status-#{status}")
  end

  def money(amount_cents, currency)
    number_to_currency(amount_cents / 100.0, unit: "#{currency} ")
  end
end
