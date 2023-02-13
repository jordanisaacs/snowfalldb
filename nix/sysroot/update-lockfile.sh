#!/usr/bin/env nix-shell
#!nix-shell -i bash -p python3 python3.pkgs.toml cargo jq gnused
set -eu pipefile

set -x

HERE=$(readlink -e $(dirname "${BASH_SOURCE[0]}"))

# https://unix.stackexchange.com/a/84980/390173
tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'update-lockfile')
cd "$tempdir"
mkdir -p src
touch src/lib.rs

RUSTC_SRC=$(nix build "$HERE#nightlyRust.rustLibSrc" --no-link --print-out-paths)
STORE_DIR=$(nix eval --raw --expr "builtins.storeDir")

ln -s $RUSTC_SRC/{core,alloc} ./

export RUSTC_SRC
python3 "$HERE/cargo.py"

export RUSTC_BOOTSTRAP=1
cargo generate-lockfile --offline
crate2nix generate

sed -E -i Cargo.nix -e \
    "s_(/?\.\./?)*(${STORE_DIR})_\2_"

cp Cargo.lock "$HERE"
cp Cargo.nix "$HERE"

rm -rf "$tempdir"
