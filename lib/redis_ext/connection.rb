module RedisExt
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
