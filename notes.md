# DB Papers

## I/O

How much I/O do you want to handle in userspace vs kernel?

### Linux Kernel Block Layer

The block layer is the part of the kernel that implements the interface that applications/filesystems use to access storage devices.

* [Part 1: the bio layer](https://lwn.net/Articles/736534/)
* [Part 2: the request layer](https://lwn.net/Articles/738449/)

[Block-device snapshots with with blksnap module](https://lwn.net/Articles/914031/)

### [SPDK](https://spdk.io/doc/)

**All userspace*

SPDK is a way to bypass the OS and directly access an NVME storage device. It is a "user space, polled-mode, asynchronous, lockless NVME driver"

Normally drivers run in kernel space. SPDK contains drivers that run in userspace but still interface directly with the hardware device.

It does this by telling the OS to relinquish control. Done by [writing to a file in sysfs](https://lwn.net/Articles/143397/). Then it rebinds the device to either [uio](https://www.kernel.org/doc/html/latest/driver-api/uio-howto.html) or [vfio](https://www.kernel.org/doc/Documentation/vfio.txt) which act as "dummy drivers". Prevent the OS from attempting to re-bind. vfio is capable of programming the [IOMMU](https://en.wikipedia.org/wiki/Input%E2%80%93output_memory_management_unit) unlike uio. See [DMA from user space](https://spdk.io/doc/memory.html)

Once unbound, OS can't use the device anymore: eg `/dev/nvme0n1` dissapears. SPDK provides re-imagined implementations of most layers in the typical OS storage stack as c libraries.

A TiKV article on using SPDK: [link](https://www.pingcap.com/blog/tikv-and-spdk-pushing-the-limits-of-storage-performance/)

[SPDK BDev Performance Report](https://ci.spdk.io/download/performance-reports/SPDK_nvme_bdev_perf_report_2209.pdf) - A full block device layer in userspace called `bdev`

### [io-uring]()

TODO

### [The Necessary Death of the Block Device Interface](https://nivdayan.github.io/NecessaryDeath.pdf) *ssd*

TODO

### [OPTR: Order-Preserving Translation and Recovery Design for SSDs with a Standard Block Device Interface](https://www.usenix.org/system/files/atc19-chang_0.pdf)

TODO

## Page Cache/Buffer Manager

### [Are You Sure You Want to Use MMAP in Your Database Management System?](https://db.cs.cmu.edu/mmap-cidr2022/)

1. Transactional Safety
    * OS can flush dirty pages at any time, cannot prevent this
2. I/O Stalls
    * Not sure which pages in memory, can cause an i/o stall
3. Error handling
    * Validating pages
    * Any access can cause a SIGBUS
4. Performance issues
    * Each CPU core has its own TLB which can get out of sync with the page table. Thus, OS generally has to interrupt all CPU cores ("TLB Shootdown") when the page table changes.
    * Intra-kernel data structures are a scalability bottleneck

### [LeanStore: In-Memory Data Management Beyond Main Memory](https://db.in.tum.de/~leis/papers/leanstore.pdf)

*Pointer Swizzling*

### [Virtual-Memory Assisted Buffer Management](https://www.cs.cit.tum.de/fileadmin/w00cfj/dis/_my_direct_uploads/vmcache.pdf)

#### VMCache

1. Yes, you can exploit the virtual memory subsystem without losing control over eviciton and page fault handling (transactional safety, i/o stalls, and error handling)
2. A bonus is can enable dynamic page sizes due to a contiguous virtual memory range (from non-contiguous physical memory)

**Basic vmcache**

Basic vmcache suffers the same out-of-memory performance issues as mmap, identified by the mmap paper. But solves the others

1. Set up virtual memory with an anonymous mapping. No file descriptor is specified, storage is handled explicitly

```c
int flags = MAP_ANONYMOUS|MAP_PRIVATE|MAP_NORESERVE;
int prot = PROT_READ | PROT_WRITE;
char* virtMem = mmap(0, vmSize, prot, flags, -1, 0);
```

2. Add pages to cache by explicitly reading it from storage into the anonymous virtual memory. Buffer manager controls the page misses explicitly.

```c
uint64_t offset = 3 * pageSize;
pread(fd, virtMem + offset, pageSize, offset);
```

3. Evict pages before the buffer pool runs out of physical memory. `MADV_DONTNEED` removes the physical page from the page table and makes the physical memory available for future allocations.

```c
// If dirty first write
pwrite(fd, virtMem + offset, pageSize, offset)
madvise(virtMem + offset, pageSize, MADV_DONTNEED);
```

**Synchronization**

Need an additional data structure for synchronization because:

1. Not all page accesses traverse the page table. If page translation is cached in the TLB of a particular thread, does not need to consult the page table.
2. The page table cannot be directly manipulated from user space.

**Data Structure**

A contiguous array with as many page state entries as pages on storage

![](./vmcache-ds.png)

#### Page States

On startup all pages are in the `Evicted` state

## General Synchronization

* [Optimistic Lock Coupling: A Scalable and Efficient General-Purpose Synchronization Method](http://sites.computer.org/debull/A19mar/p73.pdf)

### [The ART of Practical Synchronization](https://db.in.tum.de/~leis/papers/artsync.pdf)

> To add support for concurrency, we initially started
> designing a custom protocol called Read-Optimized Write Exclusion (ROWEX) [ 14 ], which turned out to be
> non-trivial and requires modifications of the underlying data structure3. However, fairly late in the project, we
> also realized, that OLC alone (rather than as part of a more complex protocol) is sufficient to synchronize ART.
> No other changes to the data structure were necessary. Both approaches were published and experimentally
> evaluated in a followup paper [14], which shows that, despite its simplicity, OLC is efficient, scalable, and
> generally outperforms ROWEX
> 
> -- Page 75 from Optimistic Lock Coupling

## BTree

To Read:

* [Building a Bw-Tree Takes More than Just Buzz Words](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [MV-PBT: Multi-Version Index for Large Datasets and HTAP Workloads](https://arxiv.org/pdf/1910.08023.pdf)
* [Making B+ Trees Cache Conscious in Main Memory](https://dl.acm.org/doi/pdf/10.1145/342009.335449)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [Benchmarked against Bw-Tree](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [A survey of b-tree locking techniques](https://15721.courses.cs.cmu.edu/spring2017/papers/06-latching/a16-graefe.pdf)

Code:

* [index-microbench](https://github.com/wangziqi2016/index-microbench)
    * Used for the Bw-Tree paper
    * Include a b-tree implementation of OLC


### [B-trees: More than I thought I'd want to know](https://benjamincongdon.me/blog/2021/08/17/B-Trees-More-Than-I-Thought-Id-Want-to-Know/)

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

### [Modern B-Tree Techniques](https://w6113.github.io/files/papers/btreesurvey-graefe.pdf)

#### Basic B-Trees** (pg. 213-216):

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

### On Disk Layout

Links: [concept to internals](http://web.archive.org/web/20161221112438/http://www.toadworld.com/platforms/oracle/w/wiki/11001.oracle-b-tree-index-from-the-concept-to-internals)

## In Memory Data Structures

To Read:

* [](https://db.cs.cmu.edu/papers/2019/p211-sun.pdf)

Code:

* [Congee - ART-OLC concurrent adaptive radix tree](https://github.com/XiangpengHao/congee)

## LSM Tree

* [Real-Time LSM-Trees for HTAP Workloads](https://arxiv.org/pdf/2101.06801.pdf)
* [Hybrid Transactional/Analytical Processing Amplifies IO in LSM-Trees](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=9940292)
* [Revisiting the Design of LSM-tree Based OLTP Storage Engine
with Persistent Memory](http://www.cs.utah.edu/~lifeifei/papers/lsmnvm-vldb21.pdf)

## Storage Layout

* [The Design and Implementation of Modern Column-Oriented Database Systems](https://stratos.seas.harvard.edu/files/stratos/files/columnstoresfntdbs.pdf)
* [Adaptive Hybrid Indexes](https://db.in.tum.de/~anneser/ahi.pdf)

###  [Proteus: Autonomous Adapative Storage for Mixed Workloads](https://cs.uwaterloo.ca/~mtabebe/publications/abebeProteus2022SIGMOD.pdf)

#### Row Layout

*In Memory*

* Fixed-size byte array
    * Once written, becomes read-only
    * Size is determined by the table schema and columns in the partition
    * Variable sized data gets 12 bytes: 4 for data size, 8 for pointer (or data itself if fits)
    * Multi-versioned: last 8 bytes stores pointer to a byte array of the previous version of the row
* Partition maintains an array of pointers to each row's most recent version (aka byte array)

*On-Disk*

* Data is divided into index & stored data entry
    * Index contains offset into the row's data
    * Row stored same as in-memory but variable-sized data is always inlined
* Supports in-place updates if the data size does not change, otherwise requires rewriting the partition
* Buffers updates in memory and batch applies them

* [](https://cs.uwaterloo.ca/~mtabebe/publications/abebeThesis2022UW.pdf)

# Postgres Design

[Internals](https://www.interdb.jp/pg/)

# Linux Kernel

Notes on kernel internals relevant to SnowfallDB (use of exmap)

## Address Types

1. User virtual addresses: seen by user-space programs. Each proccess has its own virtual address space
2. Physical Addresses: used between processor and system's memory.
3. Kernel logical addresses: Normal address space of the kernel. `kmalloc` returns kernel logical addresses. Treated as physical addresses (usually differ by a constant offset). Macro `__pa()` in `<asm/page.h` returns the associated physical address.
4. Kernel virtual addresses: do not necessary have a linear one to one mapping to physical addresses. All logical addresses _are_ vritual addresses. `vmalloc` returns a virtual address (but no direct physical mapping)

![](./address-types.png)

# SnowfallDB Design

## Page Cache/Buffer Management

Uses the exmap kernel module with vmcache implemented over it.

* Page Sizes: Pages are minimum 4KB but supports variable page sizes due to it being contiguous virtual memory.
* Concurrency: exclusive writes, shared reads, and optimistic reads.
    * Goes to sleep (parking lot method) when cannot gain an exclusive write or shared read

### Optimistic Reads

Optimistic reads on vmcache+exmap can result in a segfault. This is because during the read the page may be evicted. Thus we need to handle the segfault. Use `sigsetjmp` and `siglongjmp` from a `SIGSEGV` handler.

#### Signal handling and non-local jumps

Links:
* [How setjmp and longjmp work](https://offlinemark.com/2016/02/09/lets-understand-setjmp-longjmp/)
* [Working with signals in Rust - some things that signal handlers can't handle](https://www.jameselford.com/blog/working-with-signals-in-rust-pt1-whats-a-signal/)
* [Unwinding through a signal handler](https://maskray.me/blog/2022-04-10-unwinding-through-signal-handler)

My port of musl setjmp/longjmp to rust: [sjlj](https://github.com/jordanisaacs/sjlj)

Safety of setjmp/longjmp in Rust:

* The [Plain Old Frame](https://blog.rust-lang.org/inside-rust/2021/01/26/ffi-unwind-longjmp.html) are frames that can be trivially deallocated. A function that calls `setjmp` cannot have any destructors.
* Also take care for [returning twice](https://github.com/rust-lang/rfcs/issues/2625) and doing volatile read/writes if that is the case

From [anonymous]: 

> you can't longjmp in a signal handler because you need to either hit the return trampoline
> or sigreturn you can modify the sigcontext to resume your setlongjmp-style context instead though

Tidbit on the return trampoline

> when the kernel delivers a signal it creates a new stack to run your handler on.
> libcs will set the return address for the stack (or the link register on other architectures etc)
> to be a "trampoline" which is just a small snippet that calls sigreturn so that returning
> from the handler resumes execution of your program correctly.
> [link to linux kernel](https://github.com/torvalds/linux/blob/d6c338a741295c04ed84679153448b2fffd2c9cf/arch/x86/um/signal.c#L360).
> it's that signal registering sets SA_RESTORER which the kernel sets as the return address for the signal handler stack,
> and im pretty sure libcs just have their sigaction etc always set SA_RESTORER to their sigreturn trampoline

Do not need to care about the trampoline because not using libc. At least in musl, the `SA_RESTORER` function is just the `sigreturn` syscall. It is not necessary to call `sigreturn` from a signal. It seems that the handler is not called if no `SA_RESTORER` is provided so just do it like musl with a single call to `sigreturn`.

#### Userfaultfd

`man 2 userfaultd`

File descriptor that handles page faults in user space. This is not suitable for our use case of optimistic reads because it is meant for page fault handling. The userfaultfd is polled from a second thread. When a fault occurs the faulting thread goes to sleep. The userfaultfd reader is expected to load the page in. This is not what we want as we need to accept the fault and jump out of the read (a non-local goto).

## Index

BTree for indexing (what type?)

* Optimistic lock coupling (The ART and Optimistic Lock Coupling paper)
* Contention management

## Page layout

### 

Hybrid storage layout (proteus?)

