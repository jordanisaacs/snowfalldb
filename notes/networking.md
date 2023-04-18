# Networking Primitives

## Merging the Networking Worlds (an overview)

[link](https://netdevconf.info/0x16/session.html?Merging-the-Networking-Worlds)

**RDMA and IB Verbs**

**io_uring**

**AF_XDP**

**Zero copy APIs**

## Remote Direct Memory Access (RDMA)

* Enables the network interface controller (NIC) to access memory of remote servers
* Not persistent memory aware
    * Does not directly guarantee persistent in NVM due to NIC write caches

### Two-sided communication

TCP-like with primitives `send`/`recv`

### One-sided communication

Primitives: `read`/`write`/`atomic`

Capable of accessing remote memory while bypassing the traditional network stack, kernel, and the remote CPUs

# io-uring

## io_uring and networking in 2023

[link](https://github.com/axboe/liburing/wiki/io_uring-and-networking-in-2023)

