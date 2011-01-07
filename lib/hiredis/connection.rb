require 'hiredis/hiredis_ext'

module Hiredis
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
