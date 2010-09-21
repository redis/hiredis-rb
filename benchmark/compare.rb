# Run with
#
#   $ ruby -Ilib benchmark/compare.rb
#

require 'rubygems'
require 'benchmark'
require 'redis'
require 'redis_ext'

r = Redis.new

# Create 10_000 keys with 100 byte payload
10_000.times { |i|
  key = "string%04d" % i
  r.set(key,key)
}

# Create 10_000 element list
10_000.times { |i|
  r.lpush("list", "string%04d" % i)
}

def both(b, title, &blk)
  RedisExt::Gems::Redis.unapply! rescue nil
  r = Redis.new
  b.report("ruby:#{title}") { blk.call(r) }

  RedisExt::Gems::Redis.apply! rescue nil
  r = Redis.new
  b.report(" ext:#{title}") { blk.call(r) }
end

def pipelined_get(b, num)
  title = "GET"
  title += (" (pipeline of %d)" % num) if num > 1
  both(b, title) { |r|
    10_000.times { |i|
      if num > 1
        r.pipelined {
          num.times { |j|
            r.get("string%04d" % ((i*num+j) % 10_000))
          }
        }
      else
        r.get("string%04d" % (i % 10_000))
      end
    }
  }
end

def mget(b, num)
  both(b, "MGET %d keys" % num) { |r|
    10_000.times { |i|
      keys = num.times.map { |j| "string%04d" % ((i*num+j) % 10_000) }
      r.mget(*keys)
    }
  }
end

def pipelined_lrange(b, size, num)
  title = "LRANGE 0,%d" % (size-1)
  title += (" (pipeline of %d)" % num) if num > 1
  both(b, title) { |r|
    10_000.times { |i|
      if num > 1
        r.pipelined {
          num.times { |j|
            r.lrange("list", 0, size-1)
          }
        }
      else
        r.lrange("list", 0, size-1)
      end
    }
  }
end

Benchmark.bm(50) do |b|
  mget(b,100)
  mget(b,500)
  pipelined_get(b,1)
  pipelined_get(b,10)
  pipelined_lrange(b,100,1)
  pipelined_lrange(b,100,10)
  pipelined_lrange(b,500,1)
  pipelined_lrange(b,500,10)
end
