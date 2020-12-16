# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'cotcube-bardata'
  spec.version       = File.read("#{__dir__}/VERSION")
  spec.authors       = ['Benjamin L. Tischendorf']
  spec.email         = ['donkeybridge@jtown.eu']

  spec.summary       = 'Functions to provide bardata; and some simple time series aggregations'
  spec.description   = 'Functions to provide bardata; and some simple time series aggregations '

  spec.homepage      = 'https://github.com/donkeybridge/'+ spec.name
  spec.license       = 'BSD-4-Clause'
  spec.required_ruby_version = Gem::Requirement.new('~> 2.7')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage + '/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'cotcube-indicators'
  spec.add_dependency 'yaml'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'colorize'
  spec.add_dependency 'httparty'
  spec.add_dependency 'rubyzip'


  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~>3.6'
  spec.add_development_dependency 'yard', '~>0.9'
end
