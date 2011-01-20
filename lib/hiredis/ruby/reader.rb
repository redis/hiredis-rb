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

        MINUS    = "-".freeze
        PLUS     = "+".freeze
        COLON    = ":".freeze
        DOLLAR   = "$".freeze
        ASTERISK = "*".freeze

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
        end

        def reset!
          @type = @bulk_length = @multi_bulk = @multi_bulk_length = nil
        end

        def process_error_reply
          if str = @buffer.read_line
            error = RuntimeError.new(str)
            set_error_object(error)
            reset!
            error
          else
            false
          end
        end

        def process_status_reply
          if str = @buffer.read_line
            reset!
            str
          else
            false
          end
        end

        def process_integer_reply
          if str = @buffer.read_line
            reset!
            str.to_i
          else
            false
          end
        end

        def process_bulk_reply
          @bulk_length ||= @buffer.read_int
          return false if @bulk_length.nil?

          if @bulk_length >= 0
            if @buffer.length >= @bulk_length + 2
              bulk = @buffer.read(@bulk_length)
              @buffer.read(2) # discard CRLF
              reset!
              bulk
            else
              false
            end
          else
            reset!
            nil
          end
        end

        def process_multi_bulk_reply
          @multi_bulk_length ||= @buffer.read_int
          return false if @multi_bulk_length.nil?

          if @multi_bulk_length > 0
            if @multi_bulk.nil?
              @multi_bulk = Array.new(@multi_bulk_length)
              @multi_bulk_index = 0
            end

            while @multi_bulk_index < @multi_bulk_length
              element = child.process
              break if element == false
              @multi_bulk[@multi_bulk_index] = element
              @multi_bulk_index += 1
            end

            if @multi_bulk_index == @multi_bulk_length
              multi_bulk = @multi_bulk
              reset!
              multi_bulk
            else
              false
            end
          elsif @multi_bulk_length == 0
            reset!
            []
          else
            reset!
            nil
          end
        end

        def process
          @type ||= @buffer.read(1)
          return false if @type.nil?

          case @type
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
        end
      end

      class Buffer

        CRLF = "\r\n".freeze

        def initialize
          @buffer = ""
          @pos = 0
        end

        def <<(data)
          @buffer << data
        end

        def length
          @buffer.length - @pos
        end

        # Only discard part of the buffer when we've seen enough.
        def discard!
          if @pos >= 1024
            @buffer.slice!(0, @pos)
            @pos = 0
          end
        end

        def read(bytes)
          start = @pos
          stop = start + bytes
          return nil if stop > @buffer.length

          @pos = stop
          @buffer[start, stop - start]
        end

        def read_line
          start = @pos
          stop = @buffer.index(CRLF, @pos)
          return nil if stop.nil?

          @pos = stop + 2 # include CRLF
          @buffer[start, stop - start]
        end

        def read_int
          if str = read_line
            str.to_i
          else
            nil
          end
        end
      end
    end
  end
end
