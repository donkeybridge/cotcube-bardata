#!/usr/bin/env ruby

require_relative '../lib/cotcube-bardata.rb'

symbol = ARGV[0].nil? ? nil : ARGV[0].upcase
json   = ARGV.include? 'json'

begin
  s = Cotcube::Bardata.provide_eods(threshold: 0.10, contracts_only: false, symbol: symbol, filter: :oi_part)
  if json
    p s.to_json
  else
    s.each {|x| puts x.values.to_csv}
  end
rescue
  msg = { error: 503, message: "Could not processes symbol '#{symbol}'." }
  p msg.to_json
end
