require 'hiredis/ext/hiredis_ext'

module Hiredis
  module Ext
    class Connection
      # Raise CONNRESET on EOF
      alias :_read :read
      def read
        reply = _read
        error = reply.instance_variable_get(:@__hiredis_error)
        raise error if error

        reply
      rescue EOFError
        raise Errno::ECONNRESET
      end
    end
  end
end
