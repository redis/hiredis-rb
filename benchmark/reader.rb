# Compare throughput of pure-Ruby reply reader vs extension
#
# Run with
#
#   $ ruby -Ilib benchmark/reader.rb
#

require "hiredis/ruby/reader"
require "hiredis/reader"
require "benchmark"

N = 10_000

def benchmark(b, title, klass, pipeline = 1)
  reader = klass.new

  data = "+OK\r\n"

  GC.start
  b.report("#{title}: Status reply") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "$10\r\nxxxxxxxxxx\r\n"

  GC.start
  b.report("#{title}: Bulk reply") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "*10\r\n"
  10.times { data << "$10\r\nxxxxxxxxxx\r\n" }

  GC.start
  b.report("#{title}: Multi-bulk reply") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "*1\r\n#{data}"

  GC.start
  b.report("#{title}: Nested multi-bulk reply") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end
end

Benchmark.bm(40) do |b|
  pipeline = (ARGV.shift || 1).to_i

  if defined?(Hiredis::Reader)
    benchmark(b, "Ext", Hiredis::Reader, pipeline)
    puts
  end

  if defined?(Hiredis::Ruby::Reader)
    benchmark(b, "Ruby", Hiredis::Ruby::Reader, pipeline)
    puts
  end
end
