#!/usr/bin/env ruby

require 'cotcube-bardata'
require 'cotcube-level'
require 'cotcube-indicators'

def exit_with_error(err)
  msg = { error: 1, message: "#{err}" }
  p msg.to_json
  exit 1
end


contract   = ARGV[0].nil? ? nil : ARGV[0].upcase

debug      = ARGV.include? 'debug'
if contract.nil?
  exit_with_error('No contract given')
end

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
interval   = 30.minutes

intrabase = []
istencil  = [] 
collector_threads = [] 

collector_threads << Thread.new do 
    istencil = Cotcube::Level::Intraday_Stencil.new( interval: 30.minutes, swap_type: :full, asset: :full, weeks: 8)
end

collector_threads << Thread.new do 
  begin
    intrabase = JSON.parse(Cotcube::Helpers::DataClient.new.get_historical(contract: contract, interval: :min30, duration: '3_W' ), symbolize_names: true)[:base].
      map{ |z| 
      z[:datetime] = DateTime.parse(z[:time])
      %i[time created_at wap trades].each{|k| z.delete(k)}
      z
    }
  rescue
    intrabase = [] 
  end
end

collector_threads.each(&:join)

base = intrabase
base.select!{|z| z[:high]}

scaleBreaks = [] 
brb  = istencil.base
brb.each_with_index.map{|z,i| 
  next if i.zero?
  if brb[i][:datetime] - brb[i-1][:datetime] > (1) and brb[i][:datetime] > base.first[:datetime] and brb[i-1][:datetime] < base.last[:datetime]
    scaleBreaks << { startValue: brb[i-1][:datetime] + 0.5 * interval, endValue: brb[i][:datetime] - 0.5 * interval }
  end
} unless base.empty?

pkg = {
  sym:    sym, 
  base:   base,
  breaks: scaleBreaks
}

puts pkg.to_json 
