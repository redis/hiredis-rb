require 'redis_ext/redis_ext'
require 'redis_ext/gems/redis'

module RedisExt
  VERSION = "0.1.0.pre2"
end

# Patch Redis::Client automatically.
if defined?(Redis::Client)
  RedisExt::Gems::Redis.apply!
end
