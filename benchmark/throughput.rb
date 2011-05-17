# Compare performance of redis-rb with and without hiredis
#
# Run with
#
#   $ ruby -Ilib benchmark/throughput.rb
#

require "rubygems"
require "benchmark"
require "redis/connection/hiredis"
require "redis/connection/ruby"
require "redis"

DB = 9

$ruby = Redis.new(:db => DB)
$ruby.client.instance_variable_set(:@connection,Redis::Connection::Ruby.new)
$hiredis = Redis.new(:db => DB)
$hiredis.client.instance_variable_set(:@connection,Redis::Connection::Hiredis.new)

# make sure both are connected
$ruby.ping
$hiredis.ping

# test if db is empty
if $ruby.dbsize > 0
  STDERR.puts "Database \##{DB} is not empty!"
  exit 1
end

def pipeline(b,num,size,title,cmd)
  commands = size.times.map { cmd }
  GC.start

  b.report("redis-rb: %2dx #{title} pipeline, #{num} times" % size) {
    num.times {
      $ruby.client.call_pipelined(commands)
    }
  }

  b.report(" hiredis: %2dx #{title} pipeline, #{num} times" % size) {
    num.times {
      $hiredis.client.call_pipelined(commands)
    }
  }
end

Benchmark.bm(50) do |b|
  pipeline(b,10000, 1, "SET", %w(set foo bar))
  pipeline(b,10000,10, "SET", %w(set foo bar))
  puts

  pipeline(b,10000, 1, "GET", %w(get foo))
  pipeline(b,10000,10, "GET", %w(get foo))
  puts

  pipeline(b,10000, 1, "LPUSH", %w(lpush list fooz))
  pipeline(b,10000,10, "LPUSH", %w(lpush list fooz))
  puts

  pipeline(b,1000, 1, "LRANGE(100)", %w(lrange list 0  99))
  puts

  pipeline(b,1000, 1, "LRANGE(1000)", %w(lrange list 0 999))
  puts

  # Clean up...
  $ruby.flushdb
end
