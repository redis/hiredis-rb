require 'hiredis/em/base'

module Hiredis

  module EM

    class Connection < Base

      def initialize
        super
        @callbacks = []
      end

      def receive_reply(reply)
        callback = @callbacks.shift
        callback.call(reply) if callback
      end

      def method_missing(sym, *args, &callback)
        send_command(sym, *args)
        @callbacks.push callback
      end
    end
  end
end
