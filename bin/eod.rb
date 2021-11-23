#!/usr/bin/env ruby

require_relative '../lib/cotcube-bardata.rb'

symbol = ARGV[0].nil? ? nil : ARGV[0].upcase

s = Cotcube::Bardata.provide_eods(threshold: 0.10, contracts_only: false, symbol: symbol, filter: :oi_part)
s.each {|x| puts x.values.to_csv}
