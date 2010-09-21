require 'rake/extensiontask'

Rake::ExtensionTask.new('redis_ext') do |task|
  # Pass --with-foo-config args to extconf.rb
  task.config_options = ARGV[1..-1]
  task.lib_dir = File.join(*['lib', 'redis_ext'])
end

namespace :hiredis do
  task :clean do
    system("cd vendor/hiredis && make clean")
  end
end

# "rake clean" should also clean bundled hiredis
Rake::Task[:clean].enhance(['hiredis:clean'])

# Build from scratch
task :build => [:clean, :compile]
