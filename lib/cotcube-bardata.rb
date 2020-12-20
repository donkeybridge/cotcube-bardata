# frozen_string_literal: true

require 'active_support'
require 'colorize'
require 'date' unless defined?(DateTime)
require 'csv'  unless defined?(CSV)
require 'yaml' unless defined?(YAML)
require 'httparty'
require 'zip'


require_relative 'cotcube-bardata/constants'
require_relative 'cotcube-bardata/init'
require_relative 'cotcube-bardata/trade_dates'
require_relative 'cotcube-bardata/daily'
#require_relative 'cotcube-bardata/quarters'
require_relative 'cotcube-bardata/eods'
require_relative 'cotcube-bardata/provide'

private_files = Dir[__dir__ + '/cotcube-bardata/private/*.rb']
private_files.each do |file| 
  # puts 'Loading private module extension ' + file.chomp
  require file.chomp
end

module Cotcube
  module Bardata

    module_function :config_path, # provides the path of configuration directory
      :config_prefix,             # provides the prefix of the configuration directory according to OS-specific FSH
      :init,                      # checks whether environment is prepared and returns the config hash
      :last_trade_date,           # Provides the most recent trade date (today or maybe last friday before weekend)
      :provide,                   # 
      :provide_daily,
      :most_liquid_for,           # the most_liquid contract for a given symbol or id, based on date or last_trade_date
      :provide_eods,              # provides a list of eods, either with data or just contracts
      :continuous,                
      :continuous_overview,

      :symbols                    # reads and provides the symbols file
    
    # please not that module_functions of source provided in private files must be published there
  end
end

