# frozen_string_literal: true

require File.expand_path('lib/authie/version', __dir__)

# rubocop:disable Gemspec/RequireMFA
Gem::Specification.new do |s|
  s.name          = 'authie'
  s.description   = 'A Rails library for storing user sessions in a backend database'
  s.summary       = s.description
  s.homepage      = 'https://github.com/adamcooke/authie'
  s.licenses      = ['MIT']
  s.version       = Authie::VERSION
  s.files         = Dir.glob('{lib,db}/**/*')
  s.require_paths = ['lib']
  s.authors       = ['Adam Cooke']
  s.email         = ['me@adamcooke.io']

  s.add_dependency 'activerecord', '>= 6.1', '< 9.0'
end
# rubocop:enable Gemspec/RequireMFA
