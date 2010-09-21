# Mixin for the redis gem (~>2.0.10), specifically Redis::Client
module RedisExt
  module Gems
    module Redis
      module Apply

        # WARNING: This code is pre-alpha and patches the
        # Redis gem pretty bad. DON'T USE IN PRODUCTION!

        def self.included(base)
          base.class_eval do
            alias :__read :read
            def read
              # Use sysread to stream data into the reader.
              while (reply = @reader.gets) === false
                buf = @sock.sysread(4096)
                raise Errno::ECONNRESET, "Connection lost" if buf.nil?
                @reader.feed(buf)
              end
              reply
            rescue Errno::EAGAIN

              # We want to make sure it reconnects on the next command after the
              # timeout. Otherwise the server may reply in the meantime leaving
              # the protocol in a desync status.
              disconnect

              raise Errno::EAGAIN, "Timeout reading from the socket"
            end

            alias :__connect :connect
            def connect
              @reader = ::RedisExt::Reader.new
              __connect
            end

            alias :__disconnect :disconnect
            def disconnect
              __disconnect
              @reader = nil
            end
          end
        end
      end

      module Unapply
        def self.included(base)
          base.class_eval do
            alias :read :__read
            undef_method :__read
            alias :connect :__connect
            undef_method :__connect
            alias :disconnect :__disconnect
            undef_method :__disconnect
          end
        end
      end

      def self.apply!
        ::Redis::Client.class_eval do
          raise "Patch was already applied" if method_defined? :__read
          include Apply
        end
      end

      def self.unapply!
        ::Redis::Client.class_eval do
          raise "Patch was not yet applied" if !method_defined? :__read
          include Unapply
        end
      end

    end # Redis
  end # Gems
end # RedisExt
