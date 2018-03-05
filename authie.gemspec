require File.expand_path('../lib/authie/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = "authie"
  s.description   = %q{A Rails library for storing user sessions in a backend database}
  s.summary       = s.description
  s.homepage      = "https://github.com/adamcooke/authie"
  s.licenses      = ['MIT']
  s.version       = Authie::VERSION
  s.files         = Dir.glob("{lib,db}/**/*")
  s.require_paths = ["lib"]
  s.authors       = ["Adam Cooke"]
  s.email         = ["me@adamcooke.io"]
  s.cert_chain    = ['certs/adamcooke.pem']
  s.signing_key   = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/
end
