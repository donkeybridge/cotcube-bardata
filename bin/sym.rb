#!/usr/bin/env ruby

require 'cotcube-level'
require 'cotcube-helpers'
include Cotcube::Helpers
require_relative '../lib/cotcube-bardata.rb'

contract   = ARGV[0].nil? ? nil : ARGV[0].upcase

begin 
  s = Cotcube::Helpers.get_id_set(symbol: contract[..1])
  p s.to_json
rescue
  msg = { error: 503, message: "Could not process contract '#{contract}'." }
  p msg.to_json
end
