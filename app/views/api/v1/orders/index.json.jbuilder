json.orders @orders do |order|
  json.partial! "api/v1/orders/order", order: order
end

json.meta do
  json.page @page
  json.per_page @per_page
end
