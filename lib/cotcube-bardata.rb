# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/time'
require 'active_support/core_ext/numeric'
require 'colorize'
require 'httparty'
require 'date' unless defined?(DateTime)
require 'csv'  unless defined?(CSV)
require 'yaml' unless defined?(YAML)
require 'cotcube-helpers'



require_relative 'cotcube-bardata/constants'
require_relative 'cotcube-bardata/init'
require_relative 'cotcube-bardata/trade_dates'
require_relative 'cotcube-bardata/daily'
require_relative 'cotcube-bardata/quarters'
require_relative 'cotcube-bardata/eods'
require_relative 'cotcube-bardata/provide'

module Cotcube
  module Bardata

    module_function :config_path, # provides the path of configuration directory
      :config_prefix,             # provides the prefix of the configuration directory according to OS-specific FSH
      :init,                      # checks whether environment is prepared and returns the config hash
      :last_trade_date,           # Provides the most recent trade date (today or maybe last friday before weekend)
      :provide,                   # 
      :most_liquid_for,           # the most_liquid contract for a given symbol or id, based on date or last_trade_date
      :provide_eods,              # provides the list of eods, either with data or just the contracts, filtered for liquidity threshold
      :provide_most_liquids_by_eod,
      :provide_daily,             # provides the list of dailies for a given symbol, which include OI. Note that the close is settlement price.
      :continuous,                # for a given date or range, provide all contracts that exceed a given threshold of volume share
      :continuous_overview,       # based on continuous, create list of when which contract was most liquid
      :provide_quarters,          # provide the list of quarters, possibly as hours or days.
      :symbols                    # reads and provides the symbols file
    
    # please not that module_functions of source provided in private files must be published there
  end
end

