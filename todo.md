# TODO

## Nix Rust Build

How do I pass `--target` to `buildRustCrate` (and what about `-Zbuild-std`)

## Remove all `libc`

* `dlmalloc`
    * Switch syscalls to rustix
    * Switch pthread calls to pulled out c-scape
* `c-scape`
    * Currently relies on a few functions from it
        * pthreads
        * dl_iterate
    * Only need to pull out the pthreads implementation
* `unwinding`
    * Implement rustix backend

## File issue for proc macro std

Pulling in a proc macro overrides the `eh_personality` and  `panic_handler` that I set.
