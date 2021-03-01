# frozen_string_literal: true

require File.expand_path('lib/authie/version', __dir__)

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
  s.add_dependency  'secure_random_string'
end
