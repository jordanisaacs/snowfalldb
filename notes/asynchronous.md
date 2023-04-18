# Asynchronous Notes

These notes cover generic non-blocking i/o & async patterns

# io-uring

## ioctl() for io_uring

[link](https://lwn.net/Articles/844875/)

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

## Missing manuals - io_uring worker pool

[link](https://blog.cloudflare.com/missing-manuals-io_uring-worker-pool/)

## Exploits

### CVE-2022-1786

[link](https://blog.kylebot.net/2022/10/16/CVE-2022-1786/)

### CVE-2022-29582

[link](https://ruia-ruia.github.io/2022/08/05/CVE-2022-29582-io-uring/)
