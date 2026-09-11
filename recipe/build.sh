#!/usr/bin/env bash
set -o xtrace -o nounset -o pipefail -o errexit

# ─── shared ─────────────────────────────────────────────────────────────────
# conda's SRC_DIR overrides common.mk:20 `SRC_DIR ?= src`, so :86 misses .prepared and clones into a non-empty dir
unset SRC_DIR
# modules are built by a nested make spawned from scripts/build.sh; jobserver tokens don't survive that, so -j must come from the environment
export MAKEFLAGS="-j${CPU_COUNT}"
# both spellings are read: lowercase by LibMR/Makefile:76 and build/hiredis/Makefile:52, uppercase by core src/Makefile:271 and redisearch's deps/hiredis/Makefile:113
export openssl_prefix="${PREFIX}" OPENSSL_PREFIX="${PREFIX}"

# ─── redisearch (search) ────────────────────────────────────────────────────
export IGNORE_MISSING_DEPS=1
export CMAKE_ARGS="${CMAKE_ARGS:-} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DBOOST_DIR=${PREFIX} -DBoost_INCLUDE_DIR=${PREFIX}/include"
if [[ "$(uname)" == Darwin ]]; then
  mkdir -p "${PWD}/.libtool-shim"
  ln -sf "${BUILD_PREFIX}/bin/${LIBTOOL}" "${PWD}/.libtool-shim/libtool"
  export PATH="${PWD}/.libtool-shim:${PATH}"
fi
search_args=(
  LTO=0
)

# ─── redisjson (ReJSON) and redisearch's Rust ffi ───────────────────────────
export LIBCLANG_PATH="${BUILD_PREFIX}/lib"

# ─── redistimeseries ────────────────────────────────────────────────────────
timeseries_args=(
  "CONFIGURE_FLAGS=--disable-libevent-regress --disable-samples"
)

make deploy PREFIX="${PREFIX}" CC="${CC}" CXX="${CXX}" LD="${CC}" \
  BUILD_TLS=yes "${search_args[@]}" "${timeseries_args[@]}"

mkdir -p "${PREFIX}/etc"
install -m0644 redis.conf "${PREFIX}/etc/redis.conf"
install -m0644 sentinel.conf "${PREFIX}/etc/redis-sentinel.conf"
