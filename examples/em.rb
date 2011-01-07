# Example of using hiredis-rb in pub/sub with EventMachine.
#
# Make sure you have both EventMachine and hiredis installed.
# Then, run the following command twice with pub *and* sub to see
# messages passing through Redis.
#
#   ruby -rubygems -Ilib examples/em.rb [pub|sub]
#
require 'eventmachine'
require 'hiredis/em'

$cnt = 0

class Publisher < Hiredis::EM::Connection
  def post_init
    publish!
  end

  def publish!
    publish "channel", "hithere" do |reply|
      $cnt += 1
      publish!
    end
  end
end

class Subscriber < Hiredis::EM::Connection
  def post_init
    subscribe "channel"
  end

  def receive_reply(reply)
    $cnt += 1
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
  num.times { EventMachine.connect("localhost", 6379, klass) }

  EventMachine::PeriodicTimer.new(1) do
    print "%s: %6d\r" % [klass.name, $cnt]
    STDOUT.flush
    $cnt = 0
  end
end
