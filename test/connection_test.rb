require 'test/unit'
require 'hiredis/ext/connection' unless RUBY_PLATFORM =~ /java/
require 'hiredis/ruby/connection'

module ConnectionTests

  attr_reader :hiredis

  DEFAULT_PORT = 6380

  def sockopt(sock, opt, unpack = "i")
    sock.getsockopt(Socket::SOL_SOCKET, opt).unpack("i").first
  end

  def knock(port)
    sock = TCPSocket.new("localhost", port)
    sock.close
  rescue
  end

  def listen(port = DEFAULT_PORT)
    IO.popen("nc -l #{port}", "r+") do |io|
      sleep 0.1 # Give nc a little time to start listening

      begin
        Thread.new do
          sleep 10 # Tests should complete in 10s
          knock port
        end

        yield io
      ensure
        hiredis.disconnect if hiredis.connected?

        # Connect to make sure netcat exits
        knock port
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

  def test_connected_tcp_has_fileno
    socket = TCPServer.new("127.0.0.1", 6380)

    hiredis.connect("127.0.0.1", DEFAULT_PORT)
    assert hiredis.fileno > $stderr.fileno
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

  def test_connect_unix_has_fileno
    path = "/tmp/hiredis-rb-test.sock"
    File.unlink(path) if File.exist?(path)
    socket = UNIXServer.new(path)

    hiredis.connect_unix(path)
    assert hiredis.fileno > $stderr.fileno
  ensure
    socket.close if socket
  end

  def test_fileno_when_disconnected
    assert_raise RuntimeError, "not connected" do
      hiredis.fileno
    end
  end

  def test_connect_tcp_with_timeout
    hiredis.timeout = 200_000

    t = Time.now
    assert_raise Errno::ETIMEDOUT do
      hiredis.connect("1.1.1.1", 59876)
    end

    assert 210_000 > (Time.now - t)
  end

  def test_connect_tcp_with_timeout_override
    hiredis.timeout = 1_000_000

    t = Time.now
    assert_raise Errno::ETIMEDOUT do
      hiredis.connect("1.1.1.1", 59876, 200_000)
    end

    assert 210_000 > (Time.now - t)
  end

  def test_read_when_disconnected
    assert_raise RuntimeError, "not connected" do
      hiredis.read
    end
  end

  def test_wrong_value_for_timeout
    assert_raise ArgumentError do
      hiredis.timeout = -10
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
      assert_raise EOFError do
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

  # Test that the Hiredis thread is scheduled after some time while waiting for
  # the descriptor to be readable.
  def test_read_against_timeout_with_other_thread
    thread = Thread.new do
      sleep 0.1 while true
    end

    listen do |_|
      hiredis.connect("localhost", DEFAULT_PORT)
      hiredis.timeout = 10_000

      assert_raise Errno::EAGAIN do
        hiredis.read
      end
    end
  ensure
    thread.kill
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

  def test_recover_from_partial_write
    listen do |server|
      hiredis.connect("localhost", 6380)

      # Find out send buffer size
      sndbuf = sockopt(hiredis.sock, Socket::SO_SNDBUF)

      # Make request that saturates the send buffer
      hiredis.write(["x" * sndbuf])

      # Flush and disconnect to signal EOF
      hiredis.flush
      hiredis.disconnect

      # Compare to data received on the other end
      formatted = "*1\r\n$#{sndbuf}\r\n#{"x" * sndbuf}\r\n"
      assert formatted == server.read
    end
  end

  #
  # This does not have consistent outcome for different operating systems...
  #
  # def test_eagain_on_write
  #   listen do |server|
  #     hiredis.connect("localhost", 6380)
  #     hiredis.timeout = 100_000

  #     # Find out buffer sizes
  #     sndbuf = sockopt(hiredis.sock, Socket::SO_SNDBUF)
  #     rcvbuf = sockopt(hiredis.sock, Socket::SO_RCVBUF)

  #     # Make request that fills both the remote receive buffer and the local
  #     # send buffer. This assumes that the size of the receive buffer on the
  #     # remote end is equal to our local receive buffer size.
  #     assert_raise Errno::EAGAIN do
  #       hiredis.write(["x" * rcvbuf * 2])
  #       hiredis.write(["x" * sndbuf * 2])
  #       hiredis.flush
  #     end
  #   end
  # end

  def test_eagain_on_write_followed_by_remote_drain
    listen do |server|
      hiredis.connect("localhost", 6380)
      hiredis.timeout = 100_000

      # Find out buffer sizes
      sndbuf = sockopt(hiredis.sock, Socket::SO_SNDBUF)
      rcvbuf = sockopt(hiredis.sock, Socket::SO_RCVBUF)

      # This thread starts reading the server buffer after 50ms. This will
      # cause the local write to first return EAGAIN, wait for the socket to
      # become writable with select(2) and retry.
      begin
        thread = Thread.new do
          sleep(0.050)
          loop do
            server.read(1024)
          end
        end

        # Make request that fills both the remote receive buffer and the local
        # send buffer. This assumes that the size of the receive buffer on the
        # remote end is equal to our local receive buffer size.
        hiredis.write(["x" * rcvbuf])
        hiredis.write(["x" * sndbuf])
        hiredis.flush
        hiredis.disconnect
      ensure
        thread.kill
      end
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
