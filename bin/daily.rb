#!/usr/bin/env ruby

require_relative '../lib/cotcube-bardata'
require 'cotcube-level'
require 'cotcube-indicators'
CcI = Cotcube::Indicators

def exit_with_error(err)
  msg = { error: 1, message: "#{err}" }
  p msg.to_json
  exit 1
end


contract   = ARGV[0].nil? ? nil : ARGV[0].upcase
if contract.nil?
  exit_with_error('No contract given')
end

output     = true

sym = Cotcube::Helpers.get_id_set(symbol: contract[..1])
# TODO: apply daylight time pimped diff to all relevant datetimes in series
timediff = if %w[ NYBOT NYMEX ].include? sym[:exchange]
             5.hours
           elsif %w[ DTB ].include? sym[:exchane]
             1.hour
           else
             6.hours
           end

continuous = %w[currencies interest indices].include? sym[:type]
intraday   = false
interval   = intraday ? 30.minutes : 1.day
ema_period = 50

indicators = {
  ema_high:    CcI.ema(key: :high,    length: ema_period,  smoothing: 2),
  ema_low:     CcI.ema(key: :low,     length: ema_period,  smoothing: 2)
}

dailybase = []
stencil   = nil
stencil = Cotcube::Level::EOD_Stencil.new( interval: :daily, swap_type: :full)
dailybase = if continuous
              Cotcube::Bardata.continuous(symbol: contract[..1], indicators: indicators)[-300..].
                map{ |z|
                  z[:datetime] = DateTime.parse(z[:date])
                  z.delete(:contracts)
                  z
                }
            else
              Cotcube::Bardata.provide_daily(contract: contract, indicators: indicators)[-300..]
            end

base = dailybase
base.select!{|z| z[:high]}

scaleBreaks = []
brb  = stencil.base
brb.each_with_index.map{|z,i|
  next if i.zero?
  if brb[i][:datetime] - brb[i-1][:datetime] > (intraday ? 1 : 1.day) and brb[i][:datetime] > base.first[:datetime] and brb[i-1][:datetime] < base.last[:datetime]
    scaleBreaks << { startValue: brb[i-1][:datetime] + 0.5 * interval, endValue: brb[i][:datetime] - 0.5 * interval }
  end
} unless base.empty?

pkg = {
       base:   base,
       breaks: scaleBreaks
}

puts pkg.to_json if output
