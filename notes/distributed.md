# Distributed Systems/Databases Notes

These notes cover everything distributed systems & databases

## The Inner Workings of Distributed Databases

[link](https://questdb.io/blog/inner-workings-distributed-databases/)

# Existing Distributed Databases

## Socrates

[link](https://www.microsoft.com/en-us/research/uploads/prod/2019/05/socrates.pdf)

## CockroachDB

[Living without atomic clocks: Where CockroachDB and Spanner diverge](https://www.cockroachlabs.com/blog/living-without-atomic-clocks/)

## Neon

General:
* Normal postgres with separated storage & compute

[link](https://neon.tech/blog/architecture-decisions-in-neon)

[video](https://www.youtube.com/watch?v=rES0yzeERns)

Serverless postgres 
* focused on being able to scale compute from 0->any
* Normal postgres servers - just the storage is changed
* Storage backend supports PITR & branching

4 components:
1. Postgres Compute
    * Can be scaled up & down (even to 0) easily
    * Streams WAL to the WAL service rather than writing to disk
    * Uses RPC calls to retrieve pages from the pageserver
2. WAL Service
    * Multiple WAL *safekeeper* nodes recieve the WAL from Postgres
    * Consensus algorithm for durability even if a safekeeper node is down
    * Ensures a single Postgres instance is the primary at a given time - prevents split-brain problems
    * Append-only I/O pattern
    * WAL is processed as it arrives
        * Once it is durable (through consensus) it is streamed to pageserver
        * The pageserver sends a message when the WAL record can be removed
3. Pageserver
    * [link](https://github.com/neondatabase/neon/blob/main/docs/pageserver-storage.md)
    * Stores committed WAL
        * Indexes and buffered in memory the streamed WAL from WAL service
        * When buffer fills up, written to a new immutable file
        * Additionally it is uploaded to cloud storage
            * A successfull upload will result in the pageserver telling safekeepers to remove the corresponding WAL records
    * Reconstructs page at a given point of WAL when requested by compute
    * Serves as a cache for what is in object storage allowing for fast random access
        * Hot data is stored fast (but less reliable) local SSDs
        * Cold data gets offloaded to object storage and brought back if needed
    * Read/write/update I/O pattern
    * Immutable Files - never modified in place
        * In the background old data is re-organized by merging and deleting old files
            * To keep read latency in check & to garbage collect old page versions no longer needed for PITR
            * Inspired by LSM trees
        * Compression is easy - can compress 1 file at a time without worrying about updating parts of the file later
    * A pageserver can contain pages from many databases -> for multi-tenancy effienctly
    * Does compute talk to a single pageserver, or are pages spread across multiple pageservers?
        * Trade-off between simplicity and availability
        * Currently a single pageserver, but will add "sharding" features later
4. Object Storage
    * Provides long-term durability of data
    * Allows for easy sharding and scaling of the storage system

# Transactions

Distributed transactions guarantee 2 properties:

1. Atomicity - all or none of the machines agree to apply updates
2. Serializability - all transactions commit in some serializable order

Encounter the issue of a performance penalty of communication & coordination among distributed machines
* When a transaction accesses multiple records over the network, it needs to be serialized with all conflicting transactions
* High-performance network is criticar

## RDMA

Rdma enabled transactions

### Deconstructing RDMA-enabled Distributed Transactions: Hybrid is Better!

Name: DrTM+H

[paper](./papers/Deconstructing-RDMA-enabled-Distributed-Transactions-Hybrid-is-Better.pdf)


### RDMA-enabled Concurrency Control Protocols for Transactions in the Cloud Era (2023)

[paper](./papers/RDMA-enabled-Concurrency-Control-Protocols-for-Transactions-in-the-Cloud-Era.pdf)

* Current state of the art RDMA-based system (DrTM+H) is not sufficient
    * Various concurrency control porotocls are used, should support multiple protocols
    * Standalone frameworks do not allow for fair and unbiased cross-protcol performance comparison
* Propose RCC, a unified and comprehensive RDMA-enabled distributed transaction processing framework
    * Supports two-phase-locking protocols
    * Advanced protocols such as MVCC
    * Recent ones such as SUNDIAL and Calvin

# Locks

## Citron: Distributed Range Lock management with One-sided RDMA (2023)

[link](https://www.youtube.com/watch?v=_Aegd52O_Hg)

# Clocks

## Exploiting a Natural Network Effect for Scalable, Fine-grianed Clock Synchronization (2018)

Name: HUYGENS

[paper](https://www.usenix.org/system/files/conference/nsdi18/nsdi18-geng.pdf)

# Distributed Shared Memory Systems

## RAMCloud Storage System

[The Case for RAMClouds Paper](./papers/The-Case-For-RAMClouds-Scalable-High-Performance-Storage-Entirely-in-DRAM.pdf)

[Full List of Papers](https://ramcloud.atlassian.net/wiki/spaces/RAM/pages/6848671/RAMCloud+Papers)

[Blog Post](https://blog.acolyer.org/2016/01/18/ramcloud/)

**Durability & Availability**

* Requirements:
    * Protect against power outages
    * Crash of a single server:
        * cannot cause data to be lost
        * impact availability for more than a few seconds
    * May need cross-datacenter replication
* Assumes guarantees about durability take effect when storage server responds to a write request
* Approaches:
    1. Replicate at least 3 copies of each object
        * too expensive as triples cost of memory & energy usage
        * Could be cheapened with parity striping but expensive crash recovery
        * Succeptible to power outages
    2. Keep single copy in DRAM but back up to local disk for every write
        * Undesirable as ties write latency to disk latency
        * leaves data unavailable if server crashes, requires replicating to other machines
    3. Buffered logging *this one is best*
        * Single copy of each object stored in DRAM of a primary server
        * Primary server forwards log entries to 2 or more backup servers
        * Write operation returns when log entries are written to DRAM in the backups
        * Backups collect log entries into batches that can be written efficiently to a log on disk, then get removed from DRAM
        * Two optimzations required for availability:
            * Disk logs must be truncated to reduce amount of data read during recovery
            * Divide DRAM of primary server into hundreds of shards, each one assigned to different backup servers
                * After a crash one backup server for each shard reads its (smaller) log in parallel
                * Also acts a temporary primary for the shard until a full copy of the lost server's DRAM can be reconstructed elsewhere

## Memory Disaggregation

### The Case for Distributed Shared-Memory Databases with RDMA-Enabled Memory Disaggregation (2022)

**A sota overview of distributed shared-memory**

[paper](./papers/The-Case-for-Distributed-Shared-Memory-Databases-with-RDMA-Enabled-Memory-Disaggregation.pdf)

* Three types:
    1. No cache, no sharding
    2. Cache, no sharding
        * Uses cache coherency
    3. Cache, sharding
        * Performs *logical sharding*
            * Maintains sharding information of the data it is responsible for
        * Caches hot data locally
        * Similar to distributed shared-nothing but has advantages:
            * Does not store entire data shard (limited to local memory)
            * Elasticity: new compute node is added only metadata (eg. range info) is copied into the new node
        * Does not need cache coherence strategy due to sharding
        * Downside is cross-shard transactions
            * Can be alleviated via dynamic resharding - efficient since DSM layer can transfer data quickly
            * Might require a distributed commit protocol (using RDMA?)
                * Research is needed on leveraging RDMA primitives in distributed commit protocols
                * Does not necessarily need 2PC, can use one-sided RDMA to check if a write is successful or not

### Generic Memory Management

The following are generic protocols for distributed memory

#### Efficient Distributed Memory Management with RDMA and Caching

Name: GAM

Type: cached, no sharding

[paper](./papers/Efficient-Distributed-Memory-Management-with-RDMA-and-Caching.pdf)

[code](https://github.com/jordanisaacs/gam)

* Software cache because remote memory access is 10x slower than local memory access

#### CoRM: COmpactable Remote Memory over RDMA

Name: CoRM

[paper](https://spcl.ethz.ch/Publications/.pdf/corm-taranov.pdf)

#### Concordia: Distributed Shared Memory with In-Network Cache Coherence

Name: Concordia

Type: cache, no sharding

[paper](./papers/Concordia-Distributed-Shared-Memory-with-In-Network-Cache-Coherence.pdf)

* Similar to GAM but backed by programmable switches for performance improvements 

### Buffer Managers

These expose buffer managers over DSM

#### One Buffer Manager to Rule Them All

Type: cache, no sharding, ssd support (extension of GAM)

[paper](./papers/One-Buffer-Manager-to-Rule-Them-All.pdf)

[code](https://github.com/jordanisaacs/cachecoherence)

*Notes not finished*

**Overview**

* Current research generalizes distributed main memory using a cache coherence protocol
    * Need more for a beyond main memory database system
* *How to combine distributed memory with traditional page caching in a buffer manager?*

**Cache Coherence Protocol**

* Distributed memory management using a cache coherence protocol
* Main memory is managed uniformly and cached to reduce remote memory accesses
* 2 layer cache: main memory & persistent storage
* Extension of the GAM protocol
    * Adds support for flexible page sizes & persistent storage
* Single access point & single lock manager, memory/data is distributed

Protocol:

* Entities are *nodes*
    * Provide interfaces for remote reads/writes
    * Every machine initializes a node at the beginning
    * Each node acts as a server to answer read/write requests
    * Has its own individual identifier used for:
        * Identifying where data is stored
        * Locking data
        * Detecting which node is responsible for data at an address
    * Has 6 roles:
        * *home node*:
            * Node where the physical data lives
            * All tasks (accesses) for the data go through the home node
        * *lock node*:
            * A single node for handling the locks of the distributed system
        * *remote nodes*: all other nodes
        * *request node*: node that requests access to data. access granted becomes:
            * *sharing node*: got read access
            * *exclusive node*/*owner node*: got exclusive write access. Essentially is now the owner of the data (even if it isn't physically there)
* Partitioned Global Address Space (PGAS) provides a logically unified view to identify memory
    * A struct that identiifes a global address with following info:
        ```c
        struct __attribute__ (( packed ) ) GlobalAddress {
           size_t size ; char * ptr ; uint16_t id ; bool isFile ; }
        ```
        * Size that is stored at address
        * Pointer to the node which hosts data
            * When in background storage pointer to filename instead
        * Node ID
        * Flag that indicates if main memory or file in background storage
* Cache item states:
    * *unshared*: data resides on home node
    * *shared*: 1+ nodes have read permission
    * *exclusive*: one remote node has write permission
* 4 operations:
    * `malloc`
    * `free`
    * `read`
        * *local read*: when stored on request node
            * can acess data right away for any data state
            * B/c not changing sharing nodes
        * *remote read*: stored at remote address
            * If cache contains required data: return cached copy
            * Else: Send a read request to associated remote node
                * Associated
    * `write`
* Buffer manager over distributed memory

API:

### Databases

These are specifically designed around databases

#### The End of a Myth: Distributed Transactions Can Scale (2017)

Name: NAM-DB

Type: cached, sharded

[link](http://www.vldb.org/pvldb/vol10/p685-zamanian.pdf/)

* Separattion of storage & memory: an in-memory database
* Compute Servers
* Memory Servers
    * Holds all data of the database system
    * They are "dumb" - only provide memory capacity & perform memory management eg allocation and gargbage collection
    * Power Failures:
        * During power failure use a UPS to persist a consistent snapshot to disk
    * Hardware Failures:
        * Replication (section 6.2)

#### ScaleStore: A Fast and Cost-Efficient Storage Engine using DRAM, NVMe, and RDMA

Name: ScaleStore

Type: cached, sharded, ssd support

[link](https://www.researchgate.net/publication/360439790_ScaleStore_A_Fast_and_Cost-Efficient_Storage_Engine_using_DRAM_NVMe_and_RDMA)

[link](https://www.cidrdb.org/cidr2023/papers/p50-ziegler.pdf)

[overview](https://muratbuffalo.blogspot.com/2023/01/is-scalable-oltp-in-cloud-solved.html)

[code](https://github.com/DataManagementLab/ScaleStore)

#### PolarDB

[paper](https://dl.acm.org/doi/pdf/10.1145/3448016.3457560)

