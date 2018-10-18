# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

User.destroy_all
Transaction.destroy_all
Watch.destroy_all
BalanceChange.destroy_all

User.create!(
  first_name: "Demo",
  last_name: "User",
  email: "demouser@example.com",
  password: "demouserpassword"
)

User.first.transactions.create!(
  symbol: "AMZN",
  shares: 100,
  time: 5.years.ago
)

User.first.transactions.create!(
  symbol: "AAPL",
  shares: 300,
  time: 4.years.ago
)

User.first.transactions.create!(
  symbol: "SBUX",
  shares: 100,
  time: 42.months.ago
)
