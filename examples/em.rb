# Example of using redis_ext in pub/sub with EventMachine.
#
# Make sure you have EventMachine installed and redis_ext compiled.
# Then, run the following command twice with pub *and* sub to see
# messages passing through Redis.
#
#   ruby -rubygems -Ilib examples/em.rb [pub|sub]
#
require 'eventmachine'
require 'redis_ext'

$cnt = 0
class Redis < EM::Connection
  def self.connect
    host = (ENV['REDIS_HOST'] || 'localhost')
    port = (ENV['REDIS_PORT'] || 6379).to_i
    EM.connect(host,port,self)
  end

  def initialize
    super
    @reader = RedisExt::Reader.new
  end

  def receive_data(data)
    @reader.feed(data)
    while reply = @reader.gets
      receive_reply(reply)
      $cnt += 1
    end
  end
end

class Publisher < Redis
  def publish!
    send_data "PUBLISH channel hithere\r\n"
  end

  def post_init
    publish!
  end

  def receive_reply(reply)
    publish!
  end
end

class Subscriber < Redis
  def post_init
    send_data "SUBSCRIBE channel\r\n"
  end

  def receive_reply(reply)
    # skip
  end
end

EventMachine.run do
  klass = case ARGV.shift
  when "pub"
    Publisher
  when "sub"
    Subscriber
  else
    raise "Specify pub or sub"
  end

  num = (ARGV.shift || 5).to_i
  num.times { klass.connect }

  EventMachine::PeriodicTimer.new(1) do
    print "%s: %6d\r" % [klass.name, $cnt]
    STDOUT.flush
    $cnt = 0
  end
end
