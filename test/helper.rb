require 'minitest/autorun'
require_relative '../lib/hiredis/ext/connection' unless RUBY_PLATFORM =~ /java|mswin|mingw/i
require_relative '../lib/hiredis/ruby/reader'
