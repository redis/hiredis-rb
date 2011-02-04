require File.expand_path("../lib/hiredis/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "hiredis"
  s.version = Hiredis::VERSION
  s.homepage = "http://github.com/pietern/hiredis-rb"
  s.authors = ["Pieter Noordhuis"]
  s.email = ["pcnoordhuis@gmail.com"]
  s.summary = "Ruby extension that wraps Hiredis (blocking connection and reply parsing)"
  s.description = s.summary

  s.require_path = "lib"
  s.extensions = Dir["ext/**/extconf.rb"]

  ext_files = Dir["ext/**/*.{rb,c,h}"]
  lib_files = Dir["lib/**/*.rb"]
  hiredis_files = Dir["vendor/hiredis/*.{c,h}"] -
        Dir["vendor/hiredis/example*"] +
        Dir["vendor/hiredis/COPYING"] +
        Dir["vendor/hiredis/Makefile"]
  s.files = %w(COPYING Rakefile) + ext_files + lib_files + hiredis_files

  s.add_development_dependency "rake-compiler", "~> 0.7.1"
end
