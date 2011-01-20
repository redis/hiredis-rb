require "socket"
require "hiredis/ruby/reader"

module Hiredis
  module Ruby
    class Connection

      def initialize
        @sock = nil
      end

      def connected?
        !! @sock
      end

      def connect(host, port)
        @reader = ::Hiredis::Ruby::Reader.new

        begin
          @sock = TCPSocket.new(host, port)
          @sock.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        rescue SocketError => error
          # Raise RuntimeError when host cannot be resolved
          if error.message.start_with?("getaddrinfo:")
            raise error.message
          else
            raise error
          end
        end
      end

      def disconnect
        @sock.close
      rescue
      ensure
        @sock = nil
      end

      def timeout=(usecs)
        raise "not connected" unless connected?

        secs   = Integer(usecs / 1_000_000)
        usecs  = Integer(usecs - (secs * 1_000_000)) # 0 - 999_999

        optval = [secs, usecs].pack("l_2")

        begin
          @sock.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
          @sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
        rescue Errno::ENOPROTOOPT
        end
      end

      def write(args)
        command = "*#{args.size}\r\n"
        args.each do |arg|
          arg = arg.to_s
          command << "$#{string_size arg}\r\n"
          command << arg
          command << "\r\n"
        end

        @sock.write(command)
      end

      def read
        raise "not connected" unless connected?

        while (reply = @reader.gets) == false
          @reader.feed @sock.sysread(1024)
        end

        error = reply.instance_variable_get(:@__hiredis_error)
        raise error if error

        reply
      rescue EOFError
        raise Errno::ECONNRESET
      end

    protected

      if "".respond_to?(:bytesize)
        def string_size(string)
          string.to_s.bytesize
        end
      else
        def string_size(string)
          string.to_s.size
        end
      end
    end
  end
end
