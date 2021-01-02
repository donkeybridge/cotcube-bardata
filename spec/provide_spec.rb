# frozen_string_literal: true

require_relative '../lib/cotcube-bardata'

tmp_root = `mktemp -d`.chomp
puts `echo 'rm -rf #{tmp_root}' | at #{(Time.now + 180).strftime('%H:%M') }`
puts "Using #{tmp_root} as data directory"
config_file_name = 'bardata.testing.yml'
config_file = "/etc/cotcube/#{config_file_name}"
config_file_content = <<-YML
---
data_path: '#{tmp_root}'
...
YML

File.write(config_file, config_file_content)
local_init = lambda { Cotcube::Bardata.init(config_file_name: config_file_name) }


RSpec.describe "Cotcube::Bardata.init" do
  it 'should not raise running .symbols' do 
    expect{Cotcube::Bardata.symbols}.not_to raise_error
  end
  it 'should not raise running .init and prepare directories' do 
    expect{Cotcube::Bardata.init(config_file_name: config_file_name)}.not_to raise_error
    ['daily', 'eods', 'quarters','trading_hours','cached'].each do |dir| 
      expect(Pathname.new("#{tmp_root}/#{dir}")).to be_directory
    end
  end
end
RSpec.describe "Cotcube::Bardata.provide" do
  context 'it should provide quarters'
  context 'it should provide hours'
  context 'it should provide days'
  context 'it should provide dailies'
  context 'it should provide weeks'
  context 'it should provide months'
end
