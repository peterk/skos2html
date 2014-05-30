# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

#
Gem::Specification.new do |s|
  s.name        = 'skos2html'
  s.version     = '0.0.5'
  s.date        = '2013-07-15'
  s.summary     = "Simple SKOS to HTML converter"
  s.description = "Convert SKOS to a clean readable HTML file."
  s.authors     = ["Peter Krantz"]
  s.email       = 'peter@peterkrantz.se'
  s.files       = ["lib/dcterms.rdf", "lib/rdf-schema.rdf", "lib/skos.rdf", "lib/skos2html.rb"]
  s.homepage    =
    'http://rubygems.org/gems/skos2html'

  s.add_dependency('rdf-rdfxml', '~> 1.0.2') # to make sure the fix for missing language attrobites is included
  s.add_dependency('linkeddata', '~> 1.0.5')
  s.add_dependency('builder')
  s.add_dependency('logger')

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-html-matchers'

end
