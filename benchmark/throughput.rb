# Compare performance of redis-rb with and without hiredis
#
# Run with
#
#   $ ruby -Ilib benchmark/throughput.rb
#

require 'rubygems'
require 'benchmark'
require 'stringio'

require 'redis'
RubyConnection = Redis::Connection

require 'hiredis'
NativeConnection = Hiredis::Connection

$ruby = Redis.new
$ruby.client.instance_variable_set(:@connection,RubyConnection.new)
$native = Redis.new
$native.client.instance_variable_set(:@connection,NativeConnection.new)

# make sure both are connected
$ruby.ping
$native.ping

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
      $native.client.call_pipelined(commands)
    }
  }
end

Benchmark.bm(50) do |b|
  pipeline(b,10000, 1, "PING", %w(ping))
  pipeline(b,10000,10, "PING", %w(ping))
  pipeline(b,10000, 1, "SET", %w(set foo bar))
  pipeline(b,10000,10, "SET", %w(set foo bar))
  pipeline(b,10000, 1, "GET", %w(get foo))
  pipeline(b,10000,10, "GET", %w(get foo))
  pipeline(b,1000, 1, "MGET(10)", %w(mget) + (["foo"] * 10))
  pipeline(b,1000,10, "MGET(10)", %w(mget) + (["foo"] * 10))
end
