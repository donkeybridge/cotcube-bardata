## 0.1.3 (December 23, 2020)
  - added .provide_most_liquids_by_eod which supports :age, filtering out files that have been updated more recently
  - added 'type' to symbols to filter for e.g. currencies
  - changed .provide_eods not to raise on missing eod-file but just to WARN

## 0.1.2 (December 22, 2020)
  - created and added .provide_quarters
  - added cotcube-helpers as new dependency to gempsec
  - added timezone to dailies and :datetime to each row
  - updated master file with new methods and sub-file
  - added eods with 2 simple mathods .most_liquid_for and .provide_eods
  - added a simple getter to access CME tradedates (to fetch last_trade_date)
  - moved daily stuff into new file, prepare .provide to become a major accessor method

## 0.1.1 (December 16, 2020)


