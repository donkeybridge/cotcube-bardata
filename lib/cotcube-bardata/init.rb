# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    def symbols(config: init, type: nil, symbol: nil)
      if config[:symbols_file].nil?
        SYMBOL_EXAMPLES
      else
        CSV
          .read(config[:symbols_file], headers: %i[id symbol ticksize power months type bcf reports name])
          .map(&:to_h)
          .map { |row| %i[ticksize power bcf].each { |z| row[z] = row[z].to_f }; row } # rubocop:disable Style/Semicolon
          .reject { |row| row[:id].nil? }
          .tap { |all| all.select! { |x| x[:type] == type } unless type.nil? }
          .tap { |all| all.select! { |x| x[:symbol] == symbol } unless symbol.nil? }
      end
    end

    def config_prefix
      os = Gem::Platform.local.os
      case os
      when 'linux'
        ''
      when 'freebsd'
        '/usr/local'
      else
        raise 'unknown architecture'
      end
    end

    def config_path
      "#{config_prefix}/etc/cotcube"
    end

    def init(config_file_name: 'bardata.yml')
      name = 'bardata'
      config_file = config_path + "/#{config_file_name}"

      config = if File.exist?(config_file)
                 YAML.safe_load(File.read(config_file)).transform_keys(&:to_sym)
               else
                 {}
               end

      defaults = {
        data_path: "#{config_prefix}/var/cotcube/#{name}"
      }

      config = defaults.merge(config)

      # part 2 of init process: Prepare directories

      save_create_directory = lambda do |directory_name|
        unless Dir.exist?(directory_name)
          begin
            `mkdir -p #{directory_name}`
            unless $CHILD_STATUS.exitstatus.zero?
              puts "Missing permissions to create or access '#{directory_name}', please clarify manually"
              exit 1 unless defined?(IRB)
            end
          rescue StandardError
            puts "Missing permissions to create or access '#{directory_name}', please clarify manually"
            exit 1 unless defined?(IRB)
          end
        end
      end
      ['', :daily, :quarters, :eods, :trading_hours, :cached].each do |path|
        dir = "#{config[:data_path]}#{path == '' ? '' : '/'}#{path}"
        save_create_directory.call(dir)
      end

      # eventually return config
      config
    end
  end
end
