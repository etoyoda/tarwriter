Gem::Specification.new do |s|
  s.name = 'tarwriter'
  s.version = '2.0.0'
  s.date = '2019-01-23'
  s.summary = 'a pure-ruby class to build/read tar archive'
  s.description = 'a pure-ruby class to build/read ustar tar archive.  You can append to exiting archive.'
  s.authors = ['TOYODA Eizi' ]
  s.email = 'toyoda.eizi@gmail.com'
  s.files = ["lib/tarwriter.rb", "lib/tarreader.rb"]
  s.homepage = "https://github.com/etoyoda/tarwriter"
  s.license = "GPL-3.0-or-later"
  s.required_ruby_version = '~> 2.3'
  s.metadata = { "source_code_uri" => "https://github.com/etoyoda/tarwriter" }
end
