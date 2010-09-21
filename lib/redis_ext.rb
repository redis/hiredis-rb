require 'redis_ext/redis_ext'
require 'redis_ext/version'
require 'redis_ext/gems/redis'

# Patch Redis::Client automatically.
if defined?(Redis::Client)
  RedisExt::Gems::Redis.apply!
end
