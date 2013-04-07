# encoding: utf-8

Gem::Specification.new do |spec|
  spec.name          = 'parser'
  spec.version       = '0.9.alpha1'
  spec.authors       = ['Peter Zotov']
  spec.email         = ['whitequark@whitequark.org']
  spec.description   = %q{A Ruby parser.}
  spec.summary       = spec.description
  spec.homepage      = 'http://github.com/whitequark/parser'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/) + %w(
                          lib/parser/lexer.rb
                          lib/parser/ruby18.rb
                       )
  spec.executables   = %w()
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9'

  spec.add_dependency             'ast',       '~> 1.0'

  spec.add_development_dependency 'bundler',   '~> 1.3'
  spec.add_development_dependency 'rake',      '~> 0.9'
  spec.add_development_dependency 'racc'

  spec.add_development_dependency 'minitest',  '~> 4.7.0'
  spec.add_development_dependency 'simplecov', '~> 0.7'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'json_pure' # for coveralls on 1.9.2

  spec.add_development_dependency 'simplecov-sublime-ruby-coverage'
end
