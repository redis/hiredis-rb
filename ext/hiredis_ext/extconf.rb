require 'mkmf'

openssl_include_dir, openssl_lib_dir = dir_config('openssl')

build_hiredis = true

with_ssl = with_config('ssl', true)

unless have_header('sys/socket.h')
  puts "Could not find <sys/socket.h> (Likely Windows)."
  puts "Skipping building hiredis. The slower, pure-ruby implementation will be used instead."
  build_hiredis = false
end

def find_openssl_library
  return false unless find_header("openssl/ssl.h")

  ret = find_library("crypto", "CRYPTO_malloc") &&
    find_library("ssl", "SSL_new")

  return ret if ret

  false
end

if with_ssl
  Logging.message "=== Checking for SSL... ===\n"
  pkg_config_found = pkg_config("openssl") && find_header("openssl/ssl.h")

  if !pkg_config_found && !find_openssl_library
    use_ssl = false

    Logging.message "=== SSL not found, skipping rediss:// support. ===\n"
    Logging.message "Makefile wasn't created. Fix the errors above.\n"

    raise "OpenSSL library could not be found.\n"
      "You can disable SSL support using the --without-ssl option. " \
      "You might want to use --with-openssl-dir=<dir> option to specify the prefix where OpenSSL " \
      "is installed."
  end
end

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

hiredis_dir = File.join(File.dirname(__FILE__), %w{.. .. vendor hiredis})
unless File.directory?(hiredis_dir)
  STDERR.puts "vendor/hiredis missing, please checkout its submodule..."
  exit 1
end

RbConfig::CONFIG['configure_args'] =~ /with-make-prog\=(\w+)/
make_program = $1 || ENV['make']
make_program ||= case RUBY_PLATFORM
when /mswin/
  'nmake'
when /(bsd|solaris)/
  'gmake'
else
  'make'
end

if build_hiredis
  build_cflags = "-I#{openssl_include_dir}" if openssl_include_dir
  build_ldflags = "-L#{openssl_lib_dir}" if openssl_lib_dir
  # Set the prefix to ensure we don't mix and match headers or libraries
  prefix = File.dirname(openssl_include_dir) if openssl_include_dir
  ssl_make_arg = "USE_SSL=1 CFLAGS=#{build_cflags} SSL_LDFLAGS=#{build_ldflags} OPENSSL_PREFIX=#{prefix}" if with_ssl

  # Make sure hiredis is built...
  Dir.chdir(hiredis_dir) do
    success = system("#{ssl_make_arg} #{make_program} static")
    raise "Building hiredis failed" if !success
  end

  # Statically link to hiredis (mkmf can't do this for us)
  $CFLAGS << " -I#{hiredis_dir}"
  $LDFLAGS << " #{hiredis_dir}/libhiredis.a"
  $LDFLAGS << " #{hiredis_dir}/libhiredis_ssl.a" if with_ssl

  have_func("rb_thread_fd_select")
  create_makefile('hiredis/ext/hiredis_ext')
else
  File.open("Makefile", "wb") do |f|
    dummy_makefile(".").each do |line|
      f.puts(line)
    end
  end
end
