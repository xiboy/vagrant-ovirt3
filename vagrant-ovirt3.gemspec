# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vagrant-ovirt3/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jackson Tang"]
  gem.email         = ["tangjack@square-enix.com"]
  gem.description   = %q{Vagrant provider for oVirt and RHEV v3}
  gem.summary       = %q{This vagrant plugin provides the ability to create, control, and destroy virtual machines under oVirt/RHEV}
  gem.homepage      = "https://github.com/myoung34/vagrant-ovirt3"
  gem.licenses      = ['MIT']

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "vagrant-ovirt3"
  gem.require_paths = ["lib"]
  gem.version       = VagrantPlugins::OVirtProvider::VERSION

  gem.add_runtime_dependency "fog", "~> 1.27"
  gem.add_runtime_dependency 'rbovirt', '~> 0.0', '>= 0.0.31'

  gem.add_development_dependency 'rake', '~> 0'
end

