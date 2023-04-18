# Parallelism and Concurrency Notes

These notes cover everything that one needs to know about parallelism and concurrency

## What every systems programmer should know about concurrency

[link](https://assets.bitbashing.io/papers/concurrency-primer.pdf)

# Memory models

[Understanding memory reordering](https://www.internalpointers.com/post/understanding-memory-ordering)

[Memory Consistency Models: A Tutorial](https://www.cs.utexas.edu/~bornholt/post/memory-models.html)

[Cache coherency primer](https://fgiesen.wordpress.com/2014/07/07/cache-coherency/)

[std::memory_order](https://en.cppreference.com/w/cpp/atomic/memory_order)

# Generic Synchronization

## Optimistic Lock Coupling

[Optimistic Lock Coupling: A Scalable and Efficient General-Purpose Synchronization Method](http://sites.computer.org/debull/A19mar/p73.pdf)

### The ART of Practical Synchronization

[link](https://db.in.tum.de/~leis/papers/artsync.pdf)

> To add support for concurrency, we initially started
> designing a custom protocol called Read-Optimized Write Exclusion (ROWEX) [ 14 ], which turned out to be
> non-trivial and requires modifications of the underlying data structure3. However, fairly late in the project, we
> also realized, that OLC alone (rather than as part of a more complex protocol) is sufficient to synchronize ART.
> No other changes to the data structure were necessary. Both approaches were published and experimentally
> evaluated in a followup paper [14], which shows that, despite its simplicity, OLC is efficient, scalable, and
> generally outperforms ROWEX
> 
> -- Page 75 from Optimistic Lock Coupling

# Posix Threads

For thread-locals see ./programs.md

## `man 7 pthreads`

*Thread IDs*: Each thread has a unique thread identifier (`pthread_t`). Only guaranteed to be unique within a process. System can re-use thread IDs after a terminated thread has been joined, or a detached thread has terminated.

*Cancellation*:

* `PTHREAD_CANCEL_ASYNCHRONOUS`: Thread can be canceled at any time. Must be `async-cancel-safe` functions. Cannot safely reserve any resources.
* `PTHREAD_CANCEL_DEFERRED`: Thread can be canceled at functions that are required to to be cancellation points. A thread will be cancelled if a function is called that is a cancellation point and a cancellation request is pending. Other functions not specified can also be cancellation points.

## libc/NPTL/LinuxThreads

*Implementations*:

`LinuxThreads` was original linux implementation. Not supported since glibc 2.4

`NPTL (Native POSIX Threads Library)`:
* Requires kernel 2.6 and available since glibc 2.3.2
* All threads in a process are in the same thread group, thus share the same PID
* Uses the first two real-time signals internally. Cannot be used in applications
* `POSIX.1` nonconformance: threads don't share a common nice value

`libpthread` before glibc 2.34 was a separate library. After 2.34 it was brought into the main `libc` object, `libc.so.6`. It was done after musl did it. See [source](https://developers.redhat.com/articles/2021/12/17/why-glibc-234-removed-libpthread#the_developer_view)

They are 1:1 implementations. Each thread maps to a kernel scheduling identity. Utilize the `clone(2)` syscall. Thread synchronization primitives are implemented using the `futex(2)` syscall.

## mustang/origin/c-scape

c-scape's [implementation](https://github.com/sunfishcode/mustang/tree/main/c-scape/src/threads) of posix threads are built on top of origin's [thread runtime](https://github.com/sunfishcode/mustang/blob/main/origin/src/threads.rs).

One issue with c-scape is that it is `libc` compatible so the functions are `extern "C"`. Thus required to switch from Rust to "C" ABI, then back into rust, and then into C-like syscalls. [source](https://github.com/sunfishcode/mustang/issues/123#issue-1283959957)
