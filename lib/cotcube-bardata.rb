# rubocop:disable Naming/FileName
# rubocop:enable Naming/FileName
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
require 'cotcube-indicators'
require 'parallel'

require_relative 'cotcube-bardata/constants'
require_relative 'cotcube-bardata/helpers'
require_relative 'cotcube-bardata/init'
require_relative 'cotcube-bardata/trade_dates'
require_relative 'cotcube-bardata/daily'
require_relative 'cotcube-bardata/quarters'
require_relative 'cotcube-bardata/eods'
require_relative 'cotcube-bardata/cached'
require_relative 'cotcube-bardata/provide'
require_relative 'cotcube-bardata/suggest'
require_relative 'cotcube-bardata/range_matrix'
require_relative 'cotcube-bardata/trading_hours'

module Cotcube
  module Bardata
    module_function :config_path, # provides the path of configuration directory
                    # provides the prefix of the configuration directory according to OS-specific FSH
                    :config_prefix,
                    # checks whether environment is prepared and returns the config hash
                    :init,
                    # Provides the most recent trade date (today or maybe last friday before weekend)
                    :last_trade_date,
                    :provide,
                    # the most_liquid contract for a given symbol or id, based on date or last_trade_date
                    :most_liquid_for,
                    # provides the list of eods, either with data or just the contracts,
                    # filtered for liquidity threshold
                    :provide_eods,
                    :provide_most_liquids_by_eod,
                    # provides the list of dailies for a given symbol, which include OI.
                    # Note that the close is most probably settlement price.
                    :provide_daily,
                    # for a given date or range, provide all contracts that exceed a given threshold of volume share
                    :continuous,
                    # the list of most liquid contracts (by each days volume share)
                    :continuous_ml,
                    # same list but riped one day each
                    :continuous_actual_ml,
                    # based on continuous, create list of when which contract was most liquid
                    :continuous_overview,
                    # provider estimation of current ML usability
                    :continuous_table,
                    # provide the list of quarters, possibly as hours or days.
                    :provide_quarters,
                    # some statistics to estimate daily volatility of specific contract
                    :range_matrix,
                    # create an array of ranges based on specified source data
                    :trading_hours,
                    #
                    :select_specific_date,
                    :extended_select_for_range,
                    :provide_cached,
                    :suggest_contract_for,
                    # 
                    :compare,
                    :holidays

    # please note that module_functions of source provided in private files must be published there
  end
end
