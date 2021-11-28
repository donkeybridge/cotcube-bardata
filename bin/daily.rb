#!/usr/bin/env ruby

require 'cotcube-level'
require 'cotcube-helpers'
include Cotcube::Helpers
require_relative '../lib/cotcube-bardata.rb'

contract   = ARGV[0].nil? ? nil : ARGV[0].upcase
continuous = ARGV.include? 'cont'
csv        = ARGV.include? 'csv'
json       = not(csv)

s = if continuous 
      Cotcube::Bardata.continuous(symbol: contract[..1])[-300..].
        map{ |z| 
          z[:datetime] = DateTime.parse(z[:date])
          z.delete(:contracts)
          z
      }
    else
      Cotcube::Bardata.provide_daily(contract: contract)
    end

#t = Cotcube::Level::EOD_Stencil.new(date: s.last[:date], interval: :daily, swap_type: :full)
#t.apply to: s
if json
  puts s.select{|z| z[:high]}.to_json
elsif csv
  puts CSV.generate {|csv| 
    s.select{ |z| z[:high]}.
      each  { |z| csv << z.slice(*%i[ date contract open high low close volume oi datetime dist x]).values}
  }
else 
  puts 'dunno'
end
