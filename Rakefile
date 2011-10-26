require "bundler"
Bundler::GemHelper.install_tasks

require "rake/testtask"
require "rake/extensiontask"

unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"

  Rake::ExtensionTask.new('hiredis_ext') do |task|
    # Pass --with-foo-config args to extconf.rb
    task.config_options = ARGV[1..-1] || []
    task.lib_dir = File.join(*['lib', 'hiredis', 'ext'])
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

else

  task :build do
    # no-op
  end

end

task :default => [:build, :test]

desc "Run tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
