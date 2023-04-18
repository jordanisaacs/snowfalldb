Goals:
* Separation of storage + compute
* Within compute, separation of compute + memory
* Scalable compute from 0
* Highly durable & available
* Low latency

# Coordination Servers

* Routes queries to the correct compute cluster
* Load balances queries across the compute cluster nodes
* Some sort of consensus algorithm determines the leader
    * Coordination leader handles compute cluster failovers

# Partition Clusters

* Each partition cluster sits within a single datacenter (due to RDMA)
* Can handle 0-all partitions
* If multiple partition clusters, then shared-nothing between them

* Cluster uses a cached & sharded distributed shared-memory layer
    * Does not need cache coherency protocol
    * Needs some sort of cross-shard transaction strategy (distributed commit?)
* Compute Node
    * Handles at least one logical shard
* Memory Nodes
    * Distributed memory system through RDMA
    * Asynchronous object store uploading is offloaded to the memory node
* Storage Nodes
    * 
* Durability
    * Synchronous
        * Replicate to other partition clusters if exists
        * Replicate it to the storage cluster
    * Asynchronously
        * Writes to the storage node
        * Uploads to cloud storage
* Availability
    * Memory node crashes then can failover to a replicated memory node
    * Full memory
* Multi-writer - through DSM
* Storage Nodes
    * On its own RDMA distributed storage system
    * Replicate *k* copies of memory across nodes
        * Upon recieving an RDMA write the node asynchronously writes it to disk
    * Storage nodes periodically turn logs into pages
* Compute Nodes
* Storage cluster
    * For memory disaggregation
    * Memory servers with few cpus and mostly memory
    * Connected through rdma to compute servers
    * Also contains NVMe disks
    * Availability
        * Write transactions asynchronously to blob storage & local NVMe disks
        * Recovery can come from both blob storage & local NVMe disks
    * Handles asynchronously performing replication to 
    * Exposes a unified API for page access - hides the underlying distributed memory/storage
        * Eg. "One Buffer manager to rule them all" paper
        * Asynchronous memory access, loads it into hot data if not there
        * Memory hierarchies:
            * Hot data - in-memory
            * Warm data - on-disk
            * Cold data - object storage
* Compute cluster
    * Local dram serves as a cache of the memory servers
    * Connects to the storage cluster with RDMA

# Page Layout

TBD

# Index

* Fractal tree based (cache-oblivious or B-epsilon?)
* Combine it with stratified versioned b-trees?

# Concurrency Control

TBD

## Consensus

2PC, etc. TBD


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


