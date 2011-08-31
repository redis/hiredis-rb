require 'test/unit'
require 'hiredis/ext/connection' unless RUBY_PLATFORM =~ /java/
require 'hiredis/ruby/connection'

module ConnectionTests

  attr_reader :hiredis

  DEFAULT_PORT = 6380

  def listen(port = DEFAULT_PORT)
    IO.popen("nc -l #{port}", "r+") do |io|
      sleep 0.05 # Give nc a little time to start listening

      begin
        yield io
      ensure
        hiredis.disconnect if hiredis.connected?
      end
    end
  end

  def test_connect_wrong_host
    assert_raise RuntimeError, /can't resolve/i do
      hiredis.connect("nonexisting", 6379)
    end
  end

  def test_connect_wrong_port
    assert_raise Errno::ECONNREFUSED do
      hiredis.connect("localhost", 6380)
    end
  end

  def test_connected_tcp
    socket = TCPServer.new("127.0.0.1", 6380)

    assert !hiredis.connected?
    hiredis.connect("127.0.0.1", DEFAULT_PORT)
    assert hiredis.connected?
    hiredis.disconnect
    assert !hiredis.connected?
  ensure
    socket.close if socket
  end

  def test_connect_unix
    path = "/tmp/hiredis-rb-test.sock"
    File.unlink(path) if File.exist?(path)
    socket = UNIXServer.new(path)

    assert !hiredis.connected?
    hiredis.connect_unix(path)
    assert hiredis.connected?
    hiredis.disconnect
    assert !hiredis.connected?
  ensure
    socket.close if socket
  end

  def test_connect_tcp_with_timeout
    assert_raise Errno::ETIMEDOUT do
      hiredis.connect("1.1.1.1", 59876, 500_000)
    end
  end

  def test_read_when_disconnected
    assert_raise RuntimeError, "not connected" do
      hiredis.read
    end
  end

  def test_timeout_when_disconnected
    assert_raise RuntimeError, "not connected" do
      hiredis.timeout = 1
    end
  end

  def test_wrong_value_for_timeout
    listen do |_|
      hiredis.connect("localhost", DEFAULT_PORT)

      assert_raise Errno::EDOM do
        hiredis.timeout = -10
      end
    end
  end

  def test_read_against_eof
    listen do |server|
      hiredis.connect("localhost", 6380)
      hiredis.write(["QUIT"])

      # Reply to QUIT and disconnect
      server.write "+OK\r\n"
      server.close_write

      # Reply for QUIT can be read
      assert_equal "OK", hiredis.read

      # Next read should raise
      assert_raise Errno::ECONNRESET do
        hiredis.read
      end
    end
  end

  def test_symbol_in_argument_list
    listen do |server|
      hiredis.connect("localhost", 6380)
      hiredis.write([:info])

      server.write "$2\r\nhi\r\n"

      assert_kind_of String, hiredis.read
    end
  end

  def test_read_against_timeout
    listen do |_|
      hiredis.connect("localhost", DEFAULT_PORT)
      hiredis.timeout = 10_000

      assert_raise Errno::EAGAIN do
        hiredis.read
      end
    end
  end

  def test_raise_on_error_reply
    listen do |server|
      hiredis.connect("localhost", 6380)
      hiredis.write(["GET"])

      server.write "-ERR wrong number of arguments\r\n"

      err = hiredis.read
      assert_match /wrong number of arguments/i, err.message
      assert_kind_of RuntimeError, err
    end
  end
end

if defined?(Hiredis::Ruby::Connection)
  class RubyConnectionTest < Test::Unit::TestCase
    include ConnectionTests

    def setup
      @hiredis = Hiredis::Ruby::Connection.new
    end
  end
end

if defined?(Hiredis::Ext::Connection)
  class ExtConnectionTest < Test::Unit::TestCase
    include ConnectionTests

    def setup
      @hiredis = Hiredis::Ext::Connection.new
    end
  end
end
