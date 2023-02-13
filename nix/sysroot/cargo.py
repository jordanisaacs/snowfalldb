import os
import toml

rust_src = os.environ["RUSTC_SRC"]

base = {
    "package": {
        "name": "nixpkgs-sysroot",
        "version": "0.0.0",
        "authors": ["The Rust Project Developers"],
        "edition": "2021",
    },
    "dependencies": {
        "compiler_builtins": {
            "version": "=0.1.85",
            "features": ["rustc-dep-of-std", "mem"],
        },
        "core": {
            "path": os.path.join(rust_src, "core"),
        },
        "alloc": {
            "path": os.path.join(rust_src, "alloc"),
        },
        "std": {
            "path": os.path.join(rust_src, "std"),
        },
    },
    "patch": {
        "crates-io": {
            "rustc-std-workspace-core": {
                "path": os.path.join(rust_src, "rustc-std-workspace-core"),
            },
            "rustc-std-workspace-alloc": {
                "path": os.path.join(rust_src, "rustc-std-workspace-alloc"),
            },
            "rustc-std-workspace-std": {
                "path": os.path.join(rust_src, "rustc-std-workspace-std"),
            },
        },
    },
}

out = toml.dumps(base)

with open("Cargo.toml", "x") as f:
    f.write(out)
