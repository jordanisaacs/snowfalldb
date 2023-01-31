# Kernel Memory

## Address Types

1. User virtual addresses: seen by user-space programs. Each proccess has its own virtual address space
2. Physical Addresses: used between processor and system's memory.
3. Kernel logical addresses: Normal address space of the kernel. `kmalloc` returns kernel logical addresses. Treated as physical addresses (usually differ by a constant offset). Macro `__pa()` in `<asm/page.h` returns the associated physical address.
4. Kernel virtual addresses: do not necessary have a linear one to one mapping to physical addresses. All logical addresses _are_ vritual addresses. `vmalloc` returns a virtual address (but no direct physical mapping)

![](./address-types.png)

## [Kernel GFP Flags](https://lwn.net/Articles/920891/)

TODO

## [VMTouch](https://hoytech.com/vmtouch/)

A tool to learn and control the file-system cache on unix and unix-like systems

Using it to investigate sqlite performance: [link](https://brunocalza.me/p/ff33a375-0f21-4bba-8ce2-2f472ef4e6b8/)

Linux portion that was yanked out of vmtouch: [link](https://gist.github.com/tvaleev/c3489f8a25449fcefac5847cdb05cb3c)

`man 2 mincore`

Powered by the `mincore` syscall which returns whether pages are in RAM. AKA detect if the memory will cause a page fault if accessed.

# System Calls

## [Anatomy of a system call, part 1](https://lwn.net/Articles/604287/)

Special instructions are needed to make the processor perform a transition to ring 0.
Functions are addressed by number rather than address.

In the kernel they are defined with the `SYSCALL_DEFINEn()` macro. It produces a `__SYSCALL_DEFINEx()` and a `SYSCALL_METADATA()` macro. The [metadata macro](https://lwn.net/Articles/604406/) builds a collection of metadata for tracing purposes (for `CONFIG_FTRACE_SYSCALLS`). The `__SYSCALL_DEFINEx()` expands to the actual syscall function. The type signatures are `long int` for correctly sign extending 32 bit values. They use the [asmlinkage](https://kernelnewbies.org/FAQ/asmlinkage) directive which tells that the function should expect arguments on the stack rather than registers.

To get to the function, a syscall table is used for mapping the numbers to function pointers. Syscall tables can be implemented differently for each architecture and have different syscall number mappings.

**x86_64**:

Early in the kernel's [startup](https://elixir.bootlin.com/linux/v3.14/source/arch/x86/kernel/cpu/common.c#L1277) sequence calls [syscall_init](https://elixir.bootlin.com/linux/v3.14/source/arch/x86/kernel/cpu/common.c#L1134). Uses the `wrmsrl` instruction to write values to a [model-specific register](https://wiki.osdev.org/Model_Specific_Registers). Wrties to `MSR_LSTAR` which is the x86\_64 register for `SYSCALL` instructions. We set it to `system_call`.

Table is accessed from the [system_call](https://elixir.bootlin.com/linux/v3.14/source/arch/x86/kernel/entry_64.S#L593) assembly entry point. Pushes various registers onto stack using `SAVE_ARGS` macro to match `asmlinkage` directive. Uses the RAX register to pick entry and then calls it.

![](./syscall_x86_64.png)

## [Anatomy of a system call part 2](https://lwn.net/Articles/604515/)

Lays out how some other arches work and x86\_32 syscalls on x86\_64

**vDSO (Virtual Dynamically-linked Shared Object)**:

* Also see [Linux Journal](https://www.linuxjournal.com/content/creating-vdso-colonels-other-chicken)

Some system calls read a small amount of information from the kernel, do not want the overhead of a ring transition.

TODO

*syscall tracing with `ptrace()`*

TODO

# Program Startup & ELF

## [A Whirlwind Tutorial on Creating Really Teensy ELF Executables for Linux](http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html)

libc have a `_start` and an `_exit` routine. These provide portability for starting up and ending a program. You can create your own `_start` with the GCC option `-nostartfiles`. You need to call `_exit` though. You can use the GCC option `-nostdlib` to not link any system libraries or startup files.

Can use the `exit(2)` syscall rather than the libc call.

There is still the ELF file though with a large amount of overhead. There are a variety of different sections that are produced by the assembler.

TODO: finish notes

## [How programs get run: ELF binaries](https://lwn.net/Articles/631631/)

TODO

## `man 5 elf`

TODO

## Rust

### [Origin](https://github.com/sunfishcode/mustang/tree/main/origin)

### main()

Use `#[start]` (tracking [issue](https://github.com/rust-lang/rust/issues/29633)) or override the C `main` function. [Source](https://doc.rust-lang.org/beta/unstable-book/language-features/lang-items.html#writing-an-executable-without-stdlib)

Rust stdlib uses the start function to initialize its [runtime](https://sourcegraph.com/github.com/rust-lang/rust/-/blob/library/std/src/rt.rs?L99%3A39=). A key thing to note is it uses a `panic::catch_unwind`. Panicking from a main function is undefined behavior right now (more notes in tracking issue). Inside it also calls the platform specific init. [unix init](https://sourcegraph.com/github.com/rust-lang/rust/-/blob/library/std/src/sys/unix/mod.rs?L53=).

# I/O

How much I/O do you want to handle in userspace vs kernel?

## Linux Kernel Block Layer

The block layer is the part of the kernel that implements the interface that applications/filesystems use to access storage devices.

* [Part 1: the bio layer](https://lwn.net/Articles/736534/)
* [Part 2: the request layer](https://lwn.net/Articles/738449/)

[Block-device snapshots with with blksnap module](https://lwn.net/Articles/914031/)

[Linux Kernel Labs - Block Device Drivers](https://linux-kernel-labs.github.io/refs/heads/master/labs/block_device_drivers.html)

## [SPDK](https://spdk.io/doc/)

**All userspace**

SPDK is a way to bypass the OS and directly access an NVME storage device. It is a "user space, polled-mode, asynchronous, lockless NVME driver"

Normally drivers run in kernel space. SPDK contains drivers that run in userspace but still interface directly with the hardware device.

It does this by telling the OS to relinquish control. Done by [writing to a file in sysfs](https://lwn.net/Articles/143397/). Then it rebinds the device to either [uio](https://www.kernel.org/doc/html/latest/driver-api/uio-howto.html) or [vfio](https://www.kernel.org/doc/Documentation/vfio.txt) which act as "dummy drivers". Prevent the OS from attempting to re-bind. vfio is capable of programming the [IOMMU](https://en.wikipedia.org/wiki/Input%E2%80%93output_memory_management_unit) unlike uio. See [DMA from user space](https://spdk.io/doc/memory.html)

Once unbound, OS can't use the device anymore: eg `/dev/nvme0n1` dissapears. SPDK provides re-imagined implementations of most layers in the typical OS storage stack as c libraries.

A TiKV article on using SPDK BlobFS: [link](https://www.pingcap.com/blog/tikv-and-spdk-pushing-the-limits-of-storage-performance/)

[SPDK BDev Performance Report](https://ci.spdk.io/download/performance-reports/SPDK_nvme_bdev_perf_report_2209.pdf) - A full block device layer in userspace called `bdev`

## [xnvme](https://xnvme.io/)

[Paper](https://dl.acm.org/doi/10.1145/3534056.3534936)

Provides a cross-platform user-space library that is I/O interface independent. Includes backends of its API for SPDK, io_uring, libaio, and more. According to the paper it has negligible cost.

Designed to be rapidly iterable to include new NVMe features.

## [Enabling Asynchronous I/O Passthru in NVMe-Native Applications](https://www.snia.org/educational-library/enabling-asynchronous-i-o-passthru-nvme-native-applications-2021)

TODO

## [HeuristicDB: A Hybrid Storage Database System Using a Non-Volatile Memory Block Device](https://dl.acm.org/doi/pdf/10.1145/3456727.3463774)

Use NVM storage as a block cache for conventional storage devices

## io-uring

### [ioctl() for io_uring](https://lwn.net/Articles/844875/)

Implement a field in the `file_operations` structure

```c
struct io_uring_cmd {
    struct file *file;
    struct io_uring_pdu pdu;
    void (*done)(struct io_uring_cmd *, ssize_t);
};

int (*uring_cmd)(struct io_uring_cmd *, enum io_uring_cmd_flags);
```

Handlers should not block. Instead

1. Complete immediately
2. Return error indicating operation would block
3. Run it asynchronously and signal completion by calling the given `done()` function

## [The Necessary Death of the Block Device Interface](https://nivdayan.github.io/NecessaryDeath.pdf) *ssd*

TODO

## [OPTR: Order-Preserving Translation and Recovery Design for SSDs with a Standard Block Device Interface](https://www.usenix.org/system/files/atc19-chang_0.pdf)

TODO

# Posix Threads

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

# QEMU

## Block Devices

* [A practical look at QEMU's Block Layer Primitives](https://kashyapc.fedorapeople.org/virt/LinuxCon-NA-2016/A-Practical-Look-at-QEMU-Block-Layer-Primitives-LC-NA-2016.pdf)
* [How to emulate block devices with qemu](https://blogs.oracle.com/post/how-to-emulate-block-devices-with-qemu)


# Page Cache/Buffer Manager

## [Are You Sure You Want to Use MMAP in Your Database Management System?](https://db.cs.cmu.edu/mmap-cidr2022/)

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

## [LeanStore: In-Memory Data Management Beyond Main Memory](https://db.in.tum.de/~leis/papers/leanstore.pdf)

*Pointer Swizzling*

## [Virtual-Memory Assisted Buffer Management](https://www.cs.cit.tum.de/fileadmin/w00cfj/dis/_my_direct_uploads/vmcache.pdf)

### VMCache

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

# General Synchronization

* [Optimistic Lock Coupling: A Scalable and Efficient General-Purpose Synchronization Method](http://sites.computer.org/debull/A19mar/p73.pdf)

## [The ART of Practical Synchronization](https://db.in.tum.de/~leis/papers/artsync.pdf)

> To add support for concurrency, we initially started
> designing a custom protocol called Read-Optimized Write Exclusion (ROWEX) [ 14 ], which turned out to be
> non-trivial and requires modifications of the underlying data structure3. However, fairly late in the project, we
> also realized, that OLC alone (rather than as part of a more complex protocol) is sufficient to synchronize ART.
> No other changes to the data structure were necessary. Both approaches were published and experimentally
> evaluated in a followup paper [14], which shows that, despite its simplicity, OLC is efficient, scalable, and
> generally outperforms ROWEX
> 
> -- Page 75 from Optimistic Lock Coupling

# BTree

To Read:

* [Building a Bw-Tree Takes More than Just Buzz Words](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [MV-PBT: Multi-Version Index for Large Datasets and HTAP Workloads](https://arxiv.org/pdf/1910.08023.pdf)
* [Making B+ Trees Cache Conscious in Main Memory](https://dl.acm.org/doi/pdf/10.1145/342009.335449)
* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [Benchmarked against Bw-Tree](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
* [A survey of b-tree locking techniques](https://15721.courses.cs.cmu.edu/spring2017/papers/06-latching/a16-graefe.pdf)
* [concept to internals](http://web.archive.org/web/20161221112438/http://www.toadworld.com/platforms/oracle/w/wiki/11001.oracle-b-tree-index-from-the-concept-to-internals)

Code:

* [index-microbench](https://github.com/wangziqi2016/index-microbench)
    * Used for the Bw-Tree paper
    * Include a b-tree implementation of OLC


## [B-trees: More than I thought I'd want to know](https://benjamincongdon.me/blog/2021/08/17/B-Trees-More-Than-I-Thought-Id-Want-to-Know/)

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

## [Modern B-Tree Techniques](https://w6113.github.io/files/papers/btreesurvey-graefe.pdf)

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

# Storage Layout

* [The Design and Implementation of Modern Column-Oriented Database Systems](https://stratos.seas.harvard.edu/files/stratos/files/columnstoresfntdbs.pdf)
* [Adaptive Hybrid Indexes](https://db.in.tum.de/~anneser/ahi.pdf)

##  [Proteus: Autonomous Adapative Storage for Mixed Workloads](https://cs.uwaterloo.ca/~mtabebe/publications/abebeProteus2022SIGMOD.pdf)

### Row Layout

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

# Fun Links

* [The Jargon File](http://www.catb.org/jargon/html/index.html)
