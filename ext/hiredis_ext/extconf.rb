require 'mkmf'

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

def need_header(*args)
  abort "\n--- #{args.first} is missing\n\n" if !find_header(*args)
end

def need_library(*args)
  abort "\n--- lib#{args.first} is missing\n\n" if !find_library(*args)
end

bundled_hiredis_dir = File.join(File.dirname(__FILE__), %w{.. .. vendor hiredis})
dir_config('hiredis', bundled_hiredis_dir, bundled_hiredis_dir)

# Compile hiredis when the bundled version can be found
system("cd #{bundled_hiredis_dir} && make static") if File.directory?(bundled_hiredis_dir)

need_header('hiredis.h')
need_library('hiredis', 'redisReaderCreate')
create_makefile('hiredis/ext/hiredis_ext')
