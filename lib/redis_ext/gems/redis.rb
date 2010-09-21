# Mixin for the redis gem (~>2.0.10), specifically Redis::Client
module RedisExt
  module Gems
    module Redis
      module Client

        # WARNING: This code is pre-alpha and patches the
        # Redis gem pretty bad. DON'T USE IN PRODUCTION!

        def self.included(base)
          base.class_eval do
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

      def self.register!
        ::Redis::Client.class_eval do
          include Client
        end
      end

    end # Redis
  end # Gems
end # RedisExt
