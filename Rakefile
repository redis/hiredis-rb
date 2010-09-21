require 'rake/gempackagetask'
require 'rake/extensiontask'

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'redis_ext'

GEM = 'redis_ext'
GEM_VERSION = RedisExt::VERSION
AUTHORS = ['Pieter Noordhuis']
EMAIL = "pcnoordhuis@gmail.com"
HOMEPAGE = "http://github.com/pietern/redis-ruby-ext"
SUMMARY = "Ruby extension that wraps hiredis reply parsing code"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["LICENSE"]
  s.summary = SUMMARY
  s.description = s.summary
  s.authors = AUTHORS
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.require_path = 'lib'
  s.autorequire = GEM
  s.extensions = FileList["ext/**/extconf.rb"]

  ext_files = Dir.glob("ext/**/*.{rb,c}")
  lib_files = Dir.glob("lib/**/*.rb")
  hiredis_files = Dir.glob("vendor/hiredis/*") -
    Dir.glob("vendor/hiredis/lib*")
    Dir.glob("vendor/hiredis/*.o")
  s.files = %w(LICENSE Rakefile) + ext_files + lib_files + hiredis_files
end

desc "create a gemspec file"
task :gemspec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

Rake::ExtensionTask.new('redis_ext') do |task|
  # Pass --with-foo-config args to extconf.rb
  task.config_options = ARGV[1..-1]
  task.lib_dir = File.join(*['lib', 'redis_ext'])
end

namespace :hiredis do
  task :clean do
    system("git submodule update --init")
    system("cd vendor/hiredis && make clean")
  end
end

# "rake clean" should also clean bundled hiredis
Rake::Task[:clean].enhance(['hiredis:clean'])

# Build from scratch
task :build => [:clean, :compile]
