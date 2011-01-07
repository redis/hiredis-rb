require 'hiredis/reader'

module Hiredis

  module EM

    class Base < ::EM::Connection

      CRLF = "\r\n".freeze

      def initialize
        super
        @reader = Reader.new
      end

      def receive_data(data)
        @reader.feed(data)
        while reply = @reader.gets
          receive_reply(reply)
        end
      end

      def receive_reply(reply)
      end

      def send_command(*args)
        args = args.flatten
        send_data("*" + args.size.to_s + CRLF)
        args.each do |arg|
          arg = arg.to_s
          send_data("$" + arg.size.to_s + CRLF + arg + CRLF)
        end
      end
    end
  end
end
