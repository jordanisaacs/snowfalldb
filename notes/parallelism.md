[What every systems programmer should know about concurrency](https://assets.bitbashing.io/papers/concurrency-primer.pdf)

# Memory models

[Understanding memory reordering](https://www.internalpointers.com/post/understanding-memory-ordering)

[Memory Consistency Models: A Tutorial](https://www.cs.utexas.edu/~bornholt/post/memory-models.html)

[Cache coherency primer](https://fgiesen.wordpress.com/2014/07/07/cache-coherency/)

[std::memory_order](https://en.cppreference.com/w/cpp/atomic/memory_order)

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


# Generic Synchronization

* [Optimistic Lock Coupling: A Scalable and Efficient General-Purpose Synchronization Method](http://sites.computer.org/debull/A19mar/p73.pdf)

## The ART of Practical Synchronization

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

# B-Tree

To Read:

* [Building a Bw-Tree Takes More than Just Buzz Words](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [MV-PBT: Multi-Version Index for Large Datasets and HTAP Workloads](https://arxiv.org/pdf/1910.08023.pdf)
* [Making B+ Trees Cache Conscious in Main Memory](https://dl.acm.org/doi/pdf/10.1145/342009.335449)
* [An Asymptotically Optimal Multiversion B-tree](https://www.cs.bu.edu/faculty/gkollios/ada17/LectNotes/mvbt.pdf)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [Benchmarked against Bw-Tree](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [A survey of b-tree locking techniques](https://15721.courses.cs.cmu.edu/spring2017/papers/06-latching/a16-graefe.pdf)
* [concept to internals](http://web.archive.org/web/20161221112438/http://www.toadworld.com/platforms/oracle/w/wiki/11001.oracle-b-tree-index-from-the-concept-to-internals)

Code:

* [index-microbench](https://github.com/wangziqi2016/index-microbench)
    * Used for the Bw-Tree paper
    * Include a b-tree implementation of OLC


## B-trees: More than I thought I'd want to know

[link](https://benjamincongdon.me/blog/2021/08/17/B-Trees-More-Than-I-Thought-Id-Want-to-Know/)

**Two important quantities**

1. *Key comparisons*
2. *Disk seeks*

Key comparisons scales with the dataset, cannot do much to change that. But we can influence the # of key comparisons per disk seek. Done by co-locating keys together in the on-disk layout. This is where **high fanout** comes from.

**Slotted Page Layout**

1. The header (start of page) - metadata
2. Offset pointers (after header) - point to cells
2. Cells (end of page) - variable-sized "slots" for data

Do not need to re-order/move data (aka cells), just the offset pointers

**Lookup**

Basic algorithm

1. Root node
2. Perform binary search on the *separator keys* within the node. Goo to child node
3. Go back to step 2 if not a leaf
4. If at leaf, get the data

## Modern B-Tree Techniques

[link](https://w6113.github.io/files/papers/btreesurvey-graefe.pdf)

### Basic B-Trees** (pg. 213-216):

**Types of Nodes**:

1. Single root
    * Contains at least one key and two child pointers
    * Contain separator keys
2. Branch nodes connecting root and leaves
    * Contain separator keys that may be equal to keys of current or former data
    * Only requirement is to guide the search algorithm
    * $N$ separator keys means $N + 1$ child pointers
3. Leaf nodes
    * Contain user data
    * Records in leaf nodes contain a search key + associated information
    * Associated information can be columns, a pointer, etc. (not important to this survey)

* Branch + leaf nodes are at least half full at all times
* B/c only leaf node contains user data, deletion does not affect branch nodes
* Short separator keys increases node fan-out (# of child pointers per node)
* Entries are kept in sorted order
* Only child pointers are truly required, but many implementations contain neighbor pointers.
    * Rarely a parent pointer b/c forces updates in many child nodes when parent is moved/split
* On-disk tree tends to represent child pointers as page identifiers
* Page headers include metadata information
* A node is aligned to a page size

**Fan-out math**:

* $N$ records and $L$ records per leaf -> $N/L$ leaf nodes
* $F$ average children per parent -> $log_F(N/L)$ branch levels

Ex: 9 leaf nodes, F = 3 -> $log_3(9) = 2$. Height is either 2 or 3 depending on if including leaves. Usually round up b/c root node has different fan-out

* Average space utilization is about 70%, always between 50% and 100%.
* Often more than 99% of nodes are leaf

**Algorithms**::

TBD

> • Latching coordinates threads to protect in-memory data
> structures including page images in the buffer pool. Lock-
> ing coordinates transactions to protect database contents.
>
> • Deadlock detection and resolution is usually provided for
> transactions and locks but not for threads and latches. Dead-
> lock avoidance for latches requires coding discipline and latch
> acquisition requests that fail rather than wait.
>
> • Latching is closely related to critical sections and could
> be supported by hardware, e.g., hardware transactional
> memory
>
> -- Page 268

# In Memory Data Structures

To Read:

* [](https://db.cs.cmu.edu/papers/2019/p211-sun.pdf)

Code:

* [Congee - ART-OLC concurrent adaptive radix tree](https://github.com/XiangpengHao/congee)

# LSM Tree

* [Real-Time LSM-Trees for HTAP Workloads](https://arxiv.org/pdf/2101.06801.pdf)
* [Hybrid Transactional/Analytical Processing Amplifies IO in LSM-Trees](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=9940292)
* [Revisiting the Design of LSM-tree Based OLTP Storage Engine
with Persistent Memory](http://www.cs.utah.edu/~lifeifei/papers/lsmnvm-vldb21.pdf)
