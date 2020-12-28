# frozen_string_literal: true

def verbose_toggle
  irb_context.echo = (irb_context.echo ? false : true)
end

alias vt verbose_toggle

$debug = true
IRB.conf[:USE_MULTILINE] = false
# require 'bundler'
# Bundler.require

require_relative 'lib/cotcube-bardata'
