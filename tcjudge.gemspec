Gem::Specification.new do |s|
  s.name        = 'tcjudge'
  s.version     = '1.0.1'
  s.executables << 'tcjudge'
  s.date        = '2015-11-20'
  s.summary     = 'Judges TopCoder solutions locally'
  s.description = 'tcjudge offers a simple command line tool that judges TopCoder solutions within local environment.'
  s.authors     = ['peryaudo']
  s.email       = 'peryaudo@gmail.com'
  s.files       = ['lib/tcjudge.rb', 'bin/tcjudge']
  s.homepage    = 'https://github.com/peryaudo/tcjudge'
  s.license     = 'MIT'

  s.add_runtime_dependency 'mechanize', '~> 2.7', '>= 2.7.3'
  s.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.6.2'
end
