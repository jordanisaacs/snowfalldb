- Delegate storage to an object store with S3 compatible API (eg Ceph)
- Page cache would be handled using exmap

# Logging

Using the [log](https://docs.rs/log/latest/log/) crate for lightweight logging. It is being used in no standard form and need to implement our own logger. TODO

Hook a logger up in the `.init_array` section. Not using origin's because it uses `env_logger` which uses stdlib.

## Threads

Currently using origin's [thread runtime](https://github.com/sunfishcode/mustang/blob/main/origin/src/threads.rs) with c-scape's [pthread](https://github.com/sunfishcode/mustang/blob/main/origin/src/threads.rs) implemented on top.

## Page Cache/Buffer Management

Uses the exmap kernel module with vmcache implemented over it.

* Page Sizes: Pages are minimum 4KB but supports variable page sizes due to it being contiguous virtual memory.
* Concurrency: exclusive writes, shared reads, and optimistic reads.
    * Goes to sleep (parking lot method) when cannot gain an exclusive write or shared read

### Optimistic Reads

Optimistic reads on vmcache+exmap can result in a segfault. This is because during the read the page may be evicted. Thus we need to handle the segfault. Use `sigsetjmp` and `siglongjmp` from a `SIGSEGV` handler. Not `userfaultd` because we are not trying to load the page in, instead we just want to jump out of the read (go to a non-local execution point).

## Index

BTree for indexing (what type?)

* Optimistic lock coupling (The ART and Optimistic Lock Coupling paper)
* Contention management

## Page layout

### 

Hybrid storage layout (proteus?)


