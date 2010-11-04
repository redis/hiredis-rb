require 'test/unit'
require 'hiredis'

class ReaderTest < Test::Unit::TestCase
  def setup
    @reader = Hiredis::Reader.new
  end

  def test_nil
    @reader.feed("$-1\r\n")
    assert_equal nil, @reader.gets
  end

  def test_integer
    value = 2**63-1 # largest 64-bit signed integer
    @reader.feed(":#{value.to_s}\r\n")
    assert_equal value, @reader.gets
  end

  def test_status_string
    @reader.feed("+status\r\n")
    assert_equal "status", @reader.gets
  end

  def test_error_string
    @reader.feed("-error\r\n")
    begin
      @reader.gets
    rescue RuntimeError => e
      assert_equal "error", e.message
    end
  end

  def test_empty_bulk_string
    @reader.feed("$0\r\n\r\n")
    assert_equal "", @reader.gets
  end

  def test_bulk_string
    @reader.feed("$5\r\nhello\r\n")
    assert_equal "hello", @reader.gets
  end

  def test_null_multi_bulk
    @reader.feed("*-1\r\n")
    assert_equal nil, @reader.gets
  end

  def test_empty_multi_bulk
    @reader.feed("*0\r\n")
    assert_equal [], @reader.gets
  end

  def test_multi_bulk
    @reader.feed("*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n")
    assert_equal ["hello", "world"], @reader.gets
  end

  def test_nested_multi_bulk
    @reader.feed("*2\r\n*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n$1\r\n!\r\n")
    assert_equal [["hello", "world"], "!"], @reader.gets
  end
end
