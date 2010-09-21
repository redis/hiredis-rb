# Run with
#
#   $ ruby -Ilib benchmark/compare.rb
#

require 'rubygems'
require 'benchmark'
require 'stringio'
require 'redis_ext' # require before redis to avoid auto-patching
require 'redis'

def generate_bulk(size)
  item = "x" * size
  "$#{item.size}\r\n#{item}\r\n"
end

def generate_multi_bulk(length,bulk_size)
  reply = "*#{length}\r\n"
  length.times { reply << generate_bulk(bulk_size) }
  reply
end

def patched_redis_client_socket(buf)
  client = Redis::Client.new
  buffer = StringIO.new(buf)
  client.instance_variable_set(:@sock, buffer)
  [client,buffer]
end

def redis_ext_reader(reply)
  reader = RedisExt::Reader.new
end

def both(b, num, reply, title)
  client, buffer = patched_redis_client_socket(reply)
  b.report("ruby:#{title}") {
    num.times {
      buffer.rewind
      client.read
    }
  }

  reader = RedisExt::Reader.new
  b.report(" ext:#{title}") {
    num.times {
      reader.feed reply
      reader.gets
    }
  }
end

def bulk(b, num, size)
  both(b, num, generate_bulk(size),
    "%dx bulk (%d bytes)" % [num,size])
end

def multi_bulk(b, num, size, bulk_size)
  both(b, num, generate_multi_bulk(size,bulk_size),
    "%dx multi bulk (%d items x %d bytes)" % [num,size,bulk_size])
end

Benchmark.bm(50) do |b|
  bulk(b, 100000, 10)
  bulk(b, 100000, 100)
  bulk(b, 100000, 1000)
  multi_bulk(b, 10000, 10, 10)
  multi_bulk(b, 10000, 100, 10)
  multi_bulk(b, 10000, 1000, 10)
end
