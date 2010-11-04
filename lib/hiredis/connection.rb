require 'hiredis/hiredis_ext'

module Hiredis
  class Connection
    # Raise CONNRESET on EOF
    alias :_read :read
    def read
      _read
    rescue EOFError
      raise Errno::ECONNRESET
    end
  end
end
