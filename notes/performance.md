# Tracing/Performance

Brendan Gregg's Linux Performance - [link](https://www.brendangregg.com/linuxperf.html)

[Performance Superpowers with Enhanced BPF](https://www.youtube.com/watch?v=oc9000dM9-k)

[Visualizing Performance with Flame Graphs](https://www.youtube.com/watch?v=D53T1Ejig1Q&t=1614s)

## ptrace

### Intercepting and emulating system calls with ptrace

[link](https://nullprogram.com/blog/2018/06/23/)

Ptrace to implement strace & native debuggers (eg gdb). It intercepts system calls. Can observe, mutate, or block them - means you can service the syscalls yourself. Emulate another OS?

Can only have one tracer attached to a process at a time, and has higher overhead. On linux x86-64 ptrace(2) has following signature `long ptrace(int request, pid_t pid, void *addr, void *data);`

## ftrace

### ftrace: trace your kernel #functions

[link](https://jvns.ca/blog/2017/03/19/getting-started-with-ftrace/)

### Debugging the kernel using Ftrace

[part 1 - link](https://lwn.net/Articles/365835/)
[part 2 - link](https://lwn.net/Articles/366796/)

