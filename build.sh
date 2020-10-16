#!/bin/sh
# usage: $0 version outfile
set -eu

tmpdir=$(mktemp -d)
cleanup() {
	rm -rf "${tmpdir}"
}
trap cleanup EXIT INT QUIT TERM


cd "${tmpdir}"
wget "https://github.com/lxc/lxd/releases/download/lxd-${1}/lxd-${1}.tar.gz"

gzip -cd "lxd-${1}.tar.gz" | tar -f- -x --no-same-owner


cd "lxd-${1}"
export GOPATH="${tmpdir}/lxd-${1}/_dist"

make deps

export CGO_CFLAGS="-I${GOPATH}/deps/sqlite/ -I${GOPATH}/deps/libco/ -I${GOPATH}/deps/raft/include/ -I${GOPATH}/deps/dqlite/include/"
export CGO_LDFLAGS="-L${GOPATH}/deps/sqlite/.libs/ -L${GOPATH}/deps/libco/ -L${GOPATH}/deps/raft/.libs -L${GOPATH}/deps/dqlite/.libs/"
export LD_LIBRARY_PATH="${GOPATH}/deps/sqlite/.libs/:${GOPATH}/deps/libco/:${GOPATH}/deps/raft/.libs/:${GOPATH}/deps/dqlite/.libs/"
export CGO_LDFLAGS_ALLOW="-Wl,-wrap,pthread_create"

cd "${GOPATH}/src/github.com/lxc/lxd"
make


# Packaging

mkdir -p "${tmpdir}/rootfs/opt/lxd/bin"
mkdir    "${tmpdir}/rootfs/opt/lxd/lib"
mkdir -p "${tmpdir}/rootfs/usr/local/bin"

cp "${GOPATH}/bin/"* "${tmpdir}/rootfs/opt/lxd/bin"
cp "${GOPATH}/deps/dqlite/.libs/libdqlite.so"* "${tmpdir}/rootfs/opt/lxd/lib"
cp "${GOPATH}/deps/raft/.libs/libraft.so"* "${tmpdir}/rootfs/opt/lxd/lib"
if [ -d "${GOPATH}/deps/sqlite" ]; then
	cp "${GOPATH}/deps/sqlite/.libs/libsqlite3.so"* "${tmpdir}/rootfs/opt/lxd/lib"
fi
if [ -d "${GOPATH}/deps/libco" ]; then
	cp "${GOPATH}/deps/libco/libco.so"*  "${tmpdir}/rootfs/opt/lxd/lib"
fi

cat >"${tmpdir}/rootfs/usr/local/bin/lxc"<<__EOF__
#!/bin/sh
set -eu
export LD_LIBRARY_PATH=/opt/lxd/lib
exec /opt/lxd/bin/lxc "\${@}"
__EOF__

cat >"${tmpdir}/rootfs/usr/local/bin/lxd"<<__EOF__
#!/bin/sh
set -eu
export PATH="/opt/lxd/bin:\${PATH}"
export LD_LIBRARY_PATH=/opt/lxd/lib
exec /opt/lxd/bin/lxd "\${@}"
__EOF__

chmod 0555 "${tmpdir}/rootfs/opt/lxd/bin"/*
chmod 0444 "${tmpdir}/rootfs/opt/lxd/lib"/*
chmod 0555 "${tmpdir}/rootfs/usr/local/bin"/*

(cd "${tmpdir}/rootfs" && tar --owner=root -f- -c .) | gzip -9c >"${2}"
