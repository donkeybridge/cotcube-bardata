## 0.1.12 (March 13, 2021)
  - range_matrix: adapted to accept block for range provision; added params :days_only and :last_n
  - minor fix on previous patch

## 0.1.11 (March 07, 2021)
  - daily.rb: added new technique 'caching in constants' to accelerate computation, also referring to continuous
  - provide.rb: minor change, so disregarded contracts can be used in swapproximate

## 0.1.10 (February 11, 2021)
  - Daily.rb: Added measure parameters to continous_suite
  - cached.rb: Minor fix in comparison

## 0.1.9.3 (February 08, 2021)
  - cached: minor change fixing problem to get yesterday in rth subsets

## 0.1.9.2 (February 07, 2021)
  - minor changes
  - daily#continuous_table: introducing debuglevel

## 0.1.9.1 (January 29, 2021)
  - provide: added new interval 'synth', mixing available dailies with synthetic days based on quarters
  - minor change / cleanup
  - setting gemspec to use rake 13 and changing version spec to overcome warnings

## 0.1.8 (January 27, 2021)
  - in helpers, #extended_range_for_date: fixed comparison signs
  - range_matrix: applied cops, noted appearance of Cotcube::Helpers.simple_series_stats
  - cached: Fixing wrong comparison sign
  - daily: slimmed down results for #continuous_overview

## 0.1.7 (January 14, 2021)
  - added :range parameter to :provide, hence to :provide_cached, :provide_daily
  - added forgotten module_functions

## 0.1.6 (January 07, 2021)
  - prefering datetime instead date (in helpers and daily)
  - changed keyword :set to :filter in cached, provide and trading_hours

## 0.1.5 (January 02, 2021)
  - applied some still missing cops

## 0.1.4 (January 02, 2021)
  - two minor fixes (cached.rb, daily.rb)
  - adding first (shy) specs ... to be continued
  - cotcube-bardata.rb: added dependency parallel, added new module files and functions
  - provide.rb: writing provide, the central accessor to actual bardata
  - cached.rb: implementing 'provide_cached', which manages reduced and dimished subsets of 'quarters'
  - helpers.rb: added get_id_set
  - daily.rb: applied cops
  - quarters.rb: applied cops, used new get_id_set, slimmed down content in favor of 'provide'
  - eods.rb: renamed get_id_from to get_id_set
  - added explanation to range_matrix.rb
  - added 'holidays' to trade_dates.csv, depending on according CSV
  - applied cops to init.rb
  - changed name from get_range to trading_hours
  - minor change in gemspec
  - fixed typos in README
  - added bounded versions to gemspec
  - applied cops
  - new file trading_hours.rb providing get_range(). Based on CSV data it provides a list of ranges depicting seconds since Sunday 0:00am, which in turn can be used with the helper Array.new.to_time_interval.
  - new file and method 'range_matrix', investigating high-low ranges of entire daily
  - Too bad, found copied README...fixing something quite embarassing.

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


