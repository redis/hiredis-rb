### 0.3.1

* Fix bug where one or more arguments passed to #write were garbage collected
  before being appended to the write buffer.

### 0.3.0

* Modify `Connection#connect` and `Connection#connect_unix` to accept an extra
  timeout argument. When connecting times out, `Errno::ETIMEDOUT` is raised.
  The timeout value should be given as number of microseconds to wait.

* Add support for connecting to Unix sockets via `Connection#connect_unix`.

* Drop dependency on redis-rb so it can be used independently, or in another
  library that doesn't require redis-rb.

* Add pure Ruby protocol parser and connection class to use as fallback when
  the extension cannot be loaded. These classes have the same API as the
  extension and use the same unit tests to ensure compatibility.

