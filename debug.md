# Debug Notes

## Binary

Currently segfaults in `rustix::backend::runtime::tls::startup_tls_info`

```
Program received signal SIGSEGV, Segmentation fault.
0x00005555555a25c9 in rustix::backend::runtime::tls::startup_tls_info () at src/backend/linux_raw/runtime/tls.rs:34
34	           addr: base.cast::<u8>().add((*tls_phdr).p_vaddr).cast(),
```

## Rust Build

How do I pass `--target` to `buildRustCrate` (and what about `-Zbuild-std`)
