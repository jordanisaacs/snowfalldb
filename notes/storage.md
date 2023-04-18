Key Questions:
- How much I/O do you want to handle in userspace vs kernel?
- Filesystem, block devices, etc. What to interact with?
- Separating storage & compute is key

# I/O

## Block Devices

### Linux Kernel Block Layer

The block layer is the part of the kernel that implements the interface that applications/filesystems use to access storage devices.

* [Part 1: the bio layer](https://lwn.net/Articles/736534/)
* [Part 2: the request layer](https://lwn.net/Articles/738449/)

[Block-device snapshots with with blksnap module](https://lwn.net/Articles/914031/)

[Linux Kernel Labs - Block Device Drivers](https://linux-kernel-labs.github.io/refs/heads/master/labs/block_device_drivers.html)

### The Necessary Death of the Block Device Interface

[link](https://nivdayan.github.io/NecessaryDeath.pdf) *ssd*

## SPDK

[link](https://spdk.io/doc/)

**All userspace**

SPDK is a way to bypass the OS and directly access an NVME storage device. It is a "user space, polled-mode, asynchronous, lockless NVME driver"

Normally drivers run in kernel space. SPDK contains drivers that run in userspace but still interface directly with the hardware device.

It does this by telling the OS to relinquish control. Done by [writing to a file in sysfs](https://lwn.net/Articles/143397/). Then it rebinds the device to either [uio](https://www.kernel.org/doc/html/latest/driver-api/uio-howto.html) or [vfio](https://www.kernel.org/doc/Documentation/vfio.txt) which act as "dummy drivers". Prevent the OS from attempting to re-bind. vfio is capable of programming the [IOMMU](https://en.wikipedia.org/wiki/Input%E2%80%93output_memory_management_unit) unlike uio. See [DMA from user space](https://spdk.io/doc/memory.html)

Once unbound, OS can't use the device anymore: eg `/dev/nvme0n1` dissapears. SPDK provides re-imagined implementations of most layers in the typical OS storage stack as c libraries.

A TiKV article on using SPDK BlobFS: [link](https://www.pingcap.com/blog/tikv-and-spdk-pushing-the-limits-of-storage-performance/)

[SPDK BDev Performance Report](https://ci.spdk.io/download/performance-reports/SPDK_nvme_bdev_perf_report_2209.pdf) - A full block device layer in userspace called `bdev`

## NVMe

### Character and Block Device

[link](https://serverfault.com/questions/892134/why-is-there-both-character-device-and-block-device-for-nvme)

The character device `/dev/nvme0` is the NVMe controller. While the block devices eg `/dev/nvme0n1` are storage namespaces. They behave essentially as disks. Erasing the SSD does not erase the namespaces.

### HeuristicDB: A Hybrid Storage Database System Using a Non-Volatile Memory Block Device

[link](https://dl.acm.org/doi/pdf/10.1145/3456727.3463774)

Use NVM storage as a block cache for conventional storage devices

### OPTR: Order-Preserving Translation and Recovery Design for SSDs with a Standard Block Device Interface

[link](https://www.usenix.org/system/files/atc19-chang_0.pdf)

### xnvme

[link](https://xnvme.io/)

[Paper](https://dl.acm.org/doi/10.1145/3534056.3534936)

Provides a cross-platform user-space library that is I/O interface independent. Includes backends of its API for SPDK, io_uring, libaio, and more. According to the paper it has negligible cost.

Designed to be rapidly iterable to include new NVMe features.

## Enabling Asynchronous I/O Passthru in NVMe-Native Applications

[link](https://www.snia.org/educational-library/enabling-asynchronous-i-o-passthru-nvme-native-applications-2021)

# Filesystems

## bcachefs

[The Programmer's Guide to bcache](https://bcachefs.org/Architecture/)

[bcachefs: Principles of Operation](https://bcachefs.org/bcachefs-principles-of-operation.pdf)

# Checksums

[Selecting a Checksum algorithm](http://fastcompression.blogspot.com/2012/04/selecting-checksum-algorithm.html)

# Page Cache

## Are You Sure You Want to Use MMAP in Your Database Management System?

[link](https://db.cs.cmu.edu/mmap-cidr2022/)

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

## LeanStore: In-Memory Data Management Beyond Main Memory

[link](https://db.in.tum.de/~leis/papers/leanstore.pdf)

*Pointer Swizzling*

## Virtual-Memory Assisted Buffer Management

[link](https://www.cs.cit.tum.de/fileadmin/w00cfj/dis/_my_direct_uploads/vmcache.pdf)

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

#### Page States

On startup all pages are in the `Evicted` state

# Storage Layout

* [The Design and Implementation of Modern Column-Oriented Database Systems](https://stratos.seas.harvard.edu/files/stratos/files/columnstoresfntdbs.pdf)
* [Adaptive Hybrid Indexes](https://db.in.tum.de/~anneser/ahi.pdf)

## Mainlining Databases: Supporting Fast Transactional Workloads on Universal Columnar Data File Formats

[link](https://arxiv.org/pdf/2004.14471.pdf)

## Proteus: Autonomous Adapative Storage for Mixed Workloads

[link](https://cs.uwaterloo.ca/~mtabebe/publications/abebeProteus2022SIGMOD.pdf)

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

[PostgreSQL 14 Internals](https://edu.postgrespro.com/postgresql_internals-14_en.pdf)

# CLI Tools

## VMTouch

[link](https://hoytech.com/vmtouch/)

A tool to learn and control the file-system cache on unix and unix-like systems

Using it to investigate sqlite performance: [link](https://brunocalza.me/p/ff33a375-0f21-4bba-8ce2-2f472ef4e6b8/)

Linux portion that was yanked out of vmtouch: [link](https://gist.github.com/tvaleev/c3489f8a25449fcefac5847cdb05cb3c)

`man 2 mincore`

Powered by the `mincore` syscall which returns whether pages are in RAM. AKA detect if the memory will cause a page fault if accessed.
