module Hiredis
  begin
    require "hiredis/ext/connection"
    Connection = Ext::Connection
  rescue LoadError
    require "hiredis/ruby/connection"
    Connection = Ruby::Connection
  end
end
