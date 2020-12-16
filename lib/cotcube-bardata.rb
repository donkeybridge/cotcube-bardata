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
      :provide,
      :continuous,
      :continuous_overview,

      :symbols                    # reads and provides the symbols file
    
    # please not that module_functions of source provided in private files must be published there
  end
end

