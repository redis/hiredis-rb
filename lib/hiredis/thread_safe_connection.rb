module Hiredis
  class ThreadSafeConnection
    #Spin up 8 threads by default, lazy loading is available, but this can make applications more deterministic
    STANDBY_POOL_SIZE_DEFAULT = 8
    def initialize params={}
      @standby_pool_size = params[:standby_pool_size] || STANDBY_POOL_SIZE_DEFAULT
    end

    def connect *args
      if @conns
        raise "You cannot call connect multiple times on Hiredis::ThreadSafeConnection, please create a new instance if you required this capability"
      end
      @args = args
      @conns = {}

      @standby_pool = []
      @standby_pool_size.times do
        conn = Hiredis::Connection.new
        conn.connect(*@args)
        @standby_pool << conn
      end
    end

    def client
      current_thread_id = Thread.current.object_id
      cached_client = @conns[current_thread_id]

      return cached_client if cached_client

      conn = @standby_pool.pop

      #Ran out of connections in the original pool
      if conn.nil?
        conn = Hiredis::Connection.new
        conn.connect(*@args)
      end

      @conns[current_thread_id] = conn

      return conn
    end

    def method_missing method, *args, &block
      $stderr.puts "WARN: Implementors: please implement #{method.inspect} for Hiredis::ThreadSafeConnection, proxying method for now to Hiredis::Connection"
      self.client.send(method, *args, &block)
    end

    def write args
      self.client.write args
    end

    def read
      self.client.read
    end
  end
end
