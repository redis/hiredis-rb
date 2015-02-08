### 0.6.0 (2015-02-08)

* Update to use new hiredis 0.12
* Small fixes to make tests work correctly
* Do not test on 1.8.7, 1.9.2 or ree anymore

### 0.5.3

* Add license to gemspec (see #28).

### 0.5.2

* Fix build issue on FreeBSD (see #24).

### 0.5.1

* Fix memory leak for MRI >= 1.9.2 introduced in 0.5.0 (see #22).

### 0.5.0

* Update calls to deprecated Ruby functions with their non-deprecated
  equivalents (see #20 and f85e8c65).

* Update hiredis to 0.11.0.

* Reduced number of objects to garbage collect on Rubinius (see #13).

* Configurable `make` command (see #5).

### 0.4.5

* The protocol reader now forces all strings to be encoded using
  `Encoding.default_external`.

### 0.4.4

* Make tests explicitly require files from the local tree to prevent files from
  the search path to be accidentally required.

### 0.4.3

* Fix bug that caused EAGAIN to be raised after the cumulative time spent
  waiting for the socket to become readable/writable exceeded the
  connection-wide timeout.

### 0.4.2 (unreleased)

* Use patched version of hiredis to support multi bulk depth of 2.

### 0.4.1

* Block indefinitely when timeout is set to zero.

### 0.4.0

* Refactor both the pure Ruby and the native connection class to use
  non-blocking I/O. The code now uses `IO.select` for the pure Ruby connection
  class, and `rb_thread_select` for the native connection class, to detect if a
  socket is readable/writable. This makes the code more portable (w.r.t.
  timeouts on connect/read/write), and more friendly towards threads running in
  the same interpreter (they can now be properly scheduled while hiredis blocks
  on select(2)).

* Add `#flush` method to connection class that flushes the write buffer to the
  socket. This buffer was previously only flushed whenever `#read` was called.

### 0.3.2

* Always statically link to the bundled hiredis version instead of searching
  the system-wide paths.

* Update hiredis to 0.10.0.

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

