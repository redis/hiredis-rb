require 'mkmf'

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

hiredis_dir = File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. vendor hiredis}))
unless File.directory?(hiredis_dir)
  STDERR.puts "vendor/hiredis missing, please checkout its submodule..."
  exit 1
end

RbConfig::CONFIG['configure_args'] =~ /with-make-prog\=(\w+)/
make_program = $1 || ENV['make']
unless make_program then
  make_program = (/mswin/ =~ RUBY_PLATFORM) ? 'nmake' : 'make'
end

# Make sure hiredis is built...
success = system("cd #{hiredis_dir} && #{make_program} static")
raise "Building hiredis failed" if !success

# Statically link to hiredis (mkmf can't do this for us)
$CFLAGS << " -I#{hiredis_dir}"
$LDFLAGS << " #{hiredis_dir}/libhiredis.a"

have_func("rb_thread_fd_select")
create_makefile('hiredis/ext/hiredis_ext')
