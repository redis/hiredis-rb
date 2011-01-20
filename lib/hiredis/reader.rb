module Hiredis
  begin
    require "hiredis/ext/reader"
    Reader = Ext::Reader
  rescue LoadError
    require "hiredis/ruby/reader"
    Reader = Ruby::Reader
  end
end
