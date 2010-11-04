require 'hiredis/hiredis_ext'
require 'hiredis/version'
require 'hiredis/connection'

# Make redis-rb use the Hiredis Connection class
class Redis
  Connection = ::Hiredis::Connection
end

# Load redis
require 'redis'
