require "hiredis/ext/hiredis_ext"
require "hiredis/version"
require "socket"

module Hiredis
  module Ext
    class Connection
      alias :_connect :connect

      def connect(s, c, t)
        _connect(s, c, t)
      rescue Errno::EINVAL
        raise Errno::ECONNREFUSED
      end

      alias :_disconnect :disconnect

      def disconnect
        _disconnect
      ensure
        @sock = nil
      end

      alias :_read :read

      def read
        _read
      rescue ::EOFError
        raise Errno::ECONNRESET
      end

      def sock
        @sock ||= Socket.for_fd(fileno)
      end
    end
  end
end
