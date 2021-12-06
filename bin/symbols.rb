#!/usr/bin/env ruby

require 'cotcube-helpers'

begin 
  s = Cotcube::Helpers.symbols + Cotcube::Helpers.micros
  p s.to_json
rescue
  msg = { error: 503, message: "Could not provide symbols." }
  p msg.to_json
end
