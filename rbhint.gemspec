# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'rbhint/version'
require 'English'

Gem::Specification.new do |s|
  s.name = 'rbhint'
  s.version = RbHint::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.4.0'
  s.authors = ['Zee Spencer', 'Bozhidar Batsov', 'Jonas Arvidsson', 'Yuji Nakayama']
  s.description = <<-DESCRIPTION
    RbHint is a Ruby code style checking and code formatting tool.
    It aims to encourage adoption of the community-driven Ruby Style Guide.
  DESCRIPTION

  s.email = 'zee+rbhint@zinc.coop'
  s.files = `git ls-files assets bin config lib LICENSE.txt README.md`
            .split($RS)
  s.bindir = 'exe'
  s.executables = ['rbhint']
  s.extra_rdoc_files = ['LICENSE.txt', 'README.md']
  s.homepage = 'https://github.com/zspencer/rbhint'
  s.licenses = ['MIT']
  s.summary = 'Automatic Ruby code style checking tool.'

  s.metadata = {
    'homepage_uri' => 'https://github.com/zspencer/rbhint/',
    'changelog_uri' => 'https://github.com/zspencer/rbhint/blob/development/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/zspencer/rbhint/',
    'documentation_uri' => 'https://docs.rubocop.org/',
    'bug_tracker_uri' => 'https://github.com/zspencer/rbhint/issues'
  }

  s.add_runtime_dependency('parallel', '~> 1.10')
  s.add_runtime_dependency('parser', '>= 2.7.0.1')
  s.add_runtime_dependency('rainbow', '>= 2.2.2', '< 4.0')
  s.add_runtime_dependency('regexp_parser', '>= 1.7')
  s.add_runtime_dependency('rexml')
  s.add_runtime_dependency('rubocop-ast', '>= 0.0.3')
  s.add_runtime_dependency('ruby-progressbar', '~> 1.7')
  s.add_runtime_dependency('unicode-display_width', '>= 1.4.0', '< 2.0')

  s.add_development_dependency('bundler', '>= 1.15.0', '< 3.0')
end
