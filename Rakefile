require 'rake'
require 'rake/gempackagetask'
require 'rake/testtask'

gem 'rake-compiler', '~> 0.7.1'
require "rake/extensiontask"

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'hiredis/version'

GEM = 'hiredis'
GEM_VERSION = Hiredis::VERSION
AUTHORS = ['Pieter Noordhuis']
EMAIL = "pcnoordhuis@gmail.com"
HOMEPAGE = "http://github.com/pietern/hiredis-rb"
SUMMARY = "Ruby extension that wraps Hiredis (blocking connection and reply parsing)"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["COPYING"]
  s.summary = SUMMARY
  s.description = s.summary
  s.authors = AUTHORS
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.require_path = 'lib'
  s.extensions = FileList["ext/**/extconf.rb"]

  ext_files = Dir.glob("ext/**/*.{rb,c,h}")
  lib_files = Dir.glob("lib/**/*.rb")
  hiredis_files = Dir.glob("vendor/hiredis/*.{c,h}") -
        Dir.glob("vendor/hiredis/example*") +
        Dir.glob("vendor/hiredis/COPYING") +
        Dir.glob("vendor/hiredis/Makefile")
  s.files = %w(COPYING Rakefile) + ext_files + lib_files + hiredis_files

  s.add_runtime_dependency "rake-compiler", "~> 0.7.1"
  s.add_runtime_dependency "redis", "~> 2.1.1"
end

desc "create a gemspec file"
task :gemspec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

Rake::ExtensionTask.new('hiredis_ext') do |task|
  # Pass --with-foo-config args to extconf.rb
  task.config_options = ARGV[1..-1]
  task.lib_dir = File.join(*['lib', 'hiredis'])
end

namespace :hiredis do
  task :clean do
    # Fetch hiredis if not present
    if !File.directory?("vendor/hiredis/.git")
      system("git submodule update --init")
    end
    system("cd vendor/hiredis && make clean")
  end
end

# "rake clean" should also clean bundled hiredis
Rake::Task[:clean].enhance(['hiredis:clean'])

# Build from scratch
task :build => [:clean, :compile]

desc "Run tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
end
