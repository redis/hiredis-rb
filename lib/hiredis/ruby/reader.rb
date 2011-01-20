module Hiredis
  module Ruby
    class Reader

      def initialize
        @buffer = Buffer.new
        @task = Task.new(@buffer)
      end

      def feed(data)
        @buffer << data
      end

      def gets
        reply = @task.process
        @buffer.discard!
        reply
      end

    protected

      class Task

        MINUS    = "-"[0]
        PLUS     = "+"[0]
        COLON    = ":"[0]
        DOLLAR   = "$"[0]
        ASTERISK = "*"[0]

        attr_accessor :parent
        attr_accessor :multi_bulk

        def initialize(buffer, parent = nil)
          @buffer, @parent = buffer, parent
        end

        def child
          @child ||= Task.new(@buffer, self)
        end

        def root
          parent ? parent.root : self
        end

        # Set error ivar on object itself when this is the root task,
        # otherwise on the root multi bulk.
        def set_error_object(err)
          obj = parent ? root.multi_bulk : err
          if !obj.instance_variable_defined?(:@__hiredis_error)
            obj.instance_variable_set(:@__hiredis_error, err)
          end
          err
        end

        def reset!
          @line = @type = @multi_bulk = nil
        end

        def process_error_reply
          set_error_object RuntimeError.new(@line)
        end

        def process_status_reply
          @line
        end

        def process_integer_reply
          @line.to_i
        end

        def process_bulk_reply
          bulk_length = @line.to_i

          if bulk_length >= 0
            reply = @buffer.read(bulk_length, 2)
            if reply.nil?
              false
            else
              reply
            end
          else
            nil
          end
        end

        def process_multi_bulk_reply
          multi_bulk_length = @line.to_i

          if multi_bulk_length > 0
            @multi_bulk ||= []

            while @multi_bulk.length < multi_bulk_length
              element = child.process
              break if element == false
              @multi_bulk << element
            end

            if @multi_bulk.length == multi_bulk_length
              @multi_bulk
            else
              false
            end
          elsif multi_bulk_length == 0
            []
          else
            nil
          end
        end

        def process
          @line ||= @buffer.read_line
          return false if @line.nil?

          @type ||= @line.slice!(0)

          reply = case @type
          when MINUS
            process_error_reply
          when PLUS
            process_status_reply
          when COLON
            process_integer_reply
          when DOLLAR
            process_bulk_reply
          when ASTERISK
            process_multi_bulk_reply
          else
            raise "Protocol error"
          end

          reset! if reply != false
          reply
        end
      end

      class Buffer

        CRLF = "\r\n".freeze

        def initialize
          @buffer = ""
          @length = @pos = 0
        end

        def <<(data)
          @length += data.length
          @buffer << data
        end

        def length
          @length
        end

        def empty?
          @length == 0
        end

        def discard!
          if @length == 0
            @buffer = ""
            @length = @pos = 0
          else
            if @pos >= 1024
              @buffer.slice!(0, @pos)
              @length -= @pos
              @pos = 0
            end
          end
        end

        def read(bytes, skip = 0)
          start = @pos
          stop = start + bytes + skip

          if @length >= stop
            @pos = stop
            @buffer[start, bytes]
          end
        end

        def read_line
          start = @pos
          stop = @buffer.index(CRLF, @pos)
          if stop
            @pos = stop + 2 # include CRLF
            @buffer[start, stop - start]
          end
        end
      end
    end
  end
end
