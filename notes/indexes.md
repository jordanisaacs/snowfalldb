# Database Index Notes

These notes cover everything database indexes

# Data Structures

## Comparisons

[Revisiting B+-tree vs. LSM-tree](https://www.usenix.org/publications/loginonline/revisit-b-tree-vs-lsm-tree-upon-arrival-modern-storage-hardware-built)

## Packed Memory Arrays

### Packed Memory Arrays - Rewired (2019)

Name: Rewired Memory Array (RMA)

[paper](./papers/Packed-Memory-Arrays-Rewired.pdf)
[code](https://github.com/jordanisaacs/rma)

### Fast Concurrent Reads and Updates with PMAs (2019)

[paper](./papers/Fast-Concurrent-Reads-and-Updates-with-PMAs.pdf)
[code](https://github.com/jordanisaacs/rma_concurrent)

* How to achieve parallelism & concurrency on sparse arrays
* Competitie updates with tree balanced solutions & superior scans

## LSM Tree

* [Real-Time LSM-Trees for HTAP Workloads](https://arxiv.org/pdf/2101.06801.pdf)
* [Hybrid Transactional/Analytical Processing Amplifies IO in LSM-Trees](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=9940292)
* [Revisiting the Design of LSM-tree Based OLTP Storage Engine
with Persistent Memory](http://www.cs.utah.edu/~lifeifei/papers/lsmnvm-vldb21.pdf)
* [How does the Log-Structured-Merge-Tree work?](http://bytecontinnum.com/2016/07/log-structured-merge-tree/)

## Bw-Tree

### Building a Bw-Tree Takes more than Just Buzz Words

[paper](https://www.cs.cmu.edu/~huanche1/publications/open_bwtree.pdf)
[code](https://github.com/wangziqi2016/index-microbench)
* Also includes a b-tree implementation of OLC

## B-Tree

### B-trees: More than I thought I'd want to know

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

### Modern B-Tree Techniques

[link](https://w6113.github.io/files/papers/btreesurvey-graefe.pdf)

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


To Read:

* [Contention and Space Management in B-Trees](https://www.cidrdb.org/cidr2021/papers/cidr2021_paper21.pdf)
* [Making B+ Trees Cache Conscious in Main Memory](https://dl.acm.org/doi/pdf/10.1145/342009.335449)
* [A survey of b-tree locking techniques](https://15721.courses.cs.cmu.edu/spring2017/papers/06-latching/a16-graefe.pdf)
* [concept to internals](http://web.archive.org/web/20161221112438/http://www.toadworld.com/platforms/oracle/w/wiki/11001.oracle-b-tree-index-from-the-concept-to-internals)

Code:

* [index-microbench](https://github.com/wangziqi2016/index-microbench)

### Versioned B-Trees

#### An Asymptotically optimal mutliversion B-tree (1996)

Name: Multiversion B-Tree (MVBT)

[link](./papers/An-Asymptotically-Optimal-Mutliversion-B-Tree.pdf)

#### Stratified B-trees and versioning dictionaries (2011)

Name: Stratified Doubling Array (strat-DA)

[paper](./papers/Stratified-B-Trees-and-versioning-dictionaries.pdf)
[video](./videos/Tech Talk Andy Twigg (Acunu) — Stratified B-Tree and Version.mp4)

* Supposed to supersede MVBT
* CoW B-trees do not inherit B-tree's optimality properties
* Stratified B-tree solves two problems:
    1. Fully-versioned B-tree with optimal space & same lookup times as CoW B-tree
    2. Pareto optimal query/update tradeoff curve -> fully verisoned updates in O(1) IOs with linear space
* Subsumes CoW b-trees
* Versioned dictionaries store keys and their values with an associated version tree
    * `update(key, value version)`
    * `range.query(start, end, version)` -
    * `clone(version)` - create a new version as a child of the specified version (eg PITR or snapshot)
    * `delete(version)` - delete a given version and free the space used by all keys written there
    * A versioned dictionary is an efficient implementaiton of the union of many dictionaries
        * Fully-versioned: supports arbitrary version trees
        * Partially-versioned: supports linear version trees
* strat-DA
    * Similar to COLA

**Castle: linux kernel implementaiton**

[code](https://github.com/jordanisaacs/castle)
[video](./videos/Castle Re-inventing storage for Big Data.mp4)

#### MV-PBT: Multi-Version Index for Large Datasets and HTAP Workloads (2019)

Name: Multiversion Partitioned B-Tree (MV-PBT) 

[paper](./papers/MV-PBT-Multi-Version-Indexing-for-Large-Datasets-and-HTAP-Workloads.pdf)

#### Big Dictionaries

[Big Dictonaries I: query/update tradeoffs](https://web.archive.org/web/20110227000643/http://www.acunu.com/2011/02/fully-persistent-dictionaries/)

[Big dictionaries II: Versioning](https://web.archive.org/web/20110312133730/http://www.acunu.com/2011/02/fully-persistent-dictionaries)

#### Efficient Bulk Updates on Multiversion B-trees

[link](http://www.vldb.org/pvldb/vol6/p1834-achakeev.pdf)

### B-Epsilon Trees

#### An Introduction to B-epsilon trees and write-optimization (2015)

[link](http://supertech.csail.mit.edu/papers/BenderFaJa15.pdf)

#### Fractal Trees (b-epsilon version)

Used for [BetrFS](https://betrfs.org)

[code](https://github.com/oscarlab/betrfs)

#### Hitchhiker Trees

[link](https://github.com/datacrypt-project/hitchhiker-tree)

* Immutable data structure
* Similar to Fractal trees except does not do in-place updates, instead performs path copying

### Cache-Oblivious Streaming B-Trees

#### Cache-Oblivious Streaming B-trees

[link](http://supertech.csail.mit.edu/papers/sbtree.pdf)

#### Fractal Trees (cache-oblivious version)

Originally cache-oblivious, then became cache aware (b-epsilon)

[hn comment](https://news.ycombinator.com/item?id=4799479)
[another hn comment](https://news.ycombinator.com/item?id=6227813#6228549)

[video](./videos/Fractal Tree Indexes Theory and Practice - YouTube.mkv)
[comparison to lsm, 2014](http://www.pandademo.com/wp-content/uploads/2017/12/A-Comparison-of-Fractal-Trees-to-Log-Structured-Merge-LSM-Trees.pdf)

#### Building a Lock-Free Cache-Oblivious B-Tree

[part 0](https://jahfer.com/posts/co-btree-0/)
[part 1](https://jahfer.com/posts/co-btree-1/)
[part 2](https://jahfer.com/posts/co-btree-2/)
[part 3](https://jahfer.com/posts/co-btree-3/)

## In Memory

To Read:

* [](https://db.cs.cmu.edu/papers/2019/p211-sun.pdf)

Code:

* [Congee - ART-OLC concurrent adaptive radix tree](https://github.com/XiangpengHao/congee)

