require 'test/unit'
require 'hiredis/ruby/connection'
require 'hiredis/ext/connection'

module ConnectionTests
  def test_connect_wrong_host
    assert_raise RuntimeError, /can't resolve/i do
      @conn.connect("nonexisting", 6379)
    end
  end

  def test_connect_wrong_port
    assert_raise Errno::ECONNREFUSED do
      @conn.connect("localhost", 6380)
    end
  end

  def test_connected?
    assert !@conn.connected?
    @conn.connect("localhost", 6379)
    assert @conn.connected?
    @conn.disconnect
    assert !@conn.connected?
  end

  def test_read_when_disconnected
    assert_raise RuntimeError, "not connected" do
      @conn.read
    end
  end

  def test_timeout_when_disconnected
    assert_raise RuntimeError, "not connected" do
      @conn.timeout = 1
    end
  end

  def test_wrong_value_for_timeout
    @conn.connect("localhost", 6379)
    assert_raise Errno::EDOM do
      @conn.timeout = -10
    end
  end

  def test_read_against_eof
    @conn.connect("localhost", 6379)
    @conn.write(["QUIT"])
    assert_equal "OK", @conn.read

    assert_raise Errno::ECONNRESET do
      @conn.read
    end
  end

  def test_symbol_in_argument_list
    @conn.connect("localhost", 6379)
    @conn.write([:info])
    assert_kind_of String, @conn.read
  end

  def test_read_against_timeout
    @conn.connect("localhost", 6379)
    @conn.timeout = 10_000

    assert_raise Errno::EAGAIN do
      @conn.read
    end
  end

  def test_raise_on_error_reply
    @conn.connect("localhost", 6379)
    @conn.write(["GET"])

    assert_raise RuntimeError, /wrong number of arguments/i do
      @conn.read
    end
  end
end

if defined?(Hiredis::Ruby::Connection)
  class RubyConnectionTest < Test::Unit::TestCase
    include ConnectionTests

    def setup
      @conn = Hiredis::Ruby::Connection.new
    end
  end
end

if defined?(Hiredis::Ext::Connection)
  class ExtConnectionTest < Test::Unit::TestCase
    include ConnectionTests

    def setup
      @conn = Hiredis::Ext::Connection.new
    end
  end
end
