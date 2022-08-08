require "hiredis/ext/hiredis_ext"
require "hiredis/version"
require "socket"

module Hiredis
  module Ext
    class Connection
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
        return @sock if @sock

        @sock = Socket.for_fd(fileno)
        @sock.autoclose = false
        @sock
      end
    end
  end
end
