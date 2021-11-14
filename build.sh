#!/bin/sh
# usage: $0 version outfile
set -eux

tmpdir=$(mktemp -d)
cleanup() {
	rm -rf "${tmpdir}"
}
trap cleanup EXIT INT QUIT TERM


cd "${tmpdir}"
wget "https://github.com/lxc/lxd/releases/download/lxd-${1}/lxd-${1}.tar.gz"

gzip -cd "lxd-${1}.tar.gz" | tar -f- -x --no-same-owner



cd "lxd-${1}"
make deps

vendor="${tmpdir}/lxd-${1}/vendor"
export CGO_CFLAGS="-I${vendor}/raft/include/ -I${vendor}/dqlite/include/"
export CGO_LDFLAGS="-L${vendor}/raft/.libs -L${vendor}/dqlite/.libs/"
export LD_LIBRARY_PATH="${vendor}/raft/.libs/:${vendor}/dqlite/.libs/"
export CGO_LDFLAGS_ALLOW="(-Wl,-wrap,pthread_create)|(-Wl,-z,now)"

make


# Packaging

mkdir -p "${tmpdir}/rootfs/opt/lxd/bin"
mkdir    "${tmpdir}/rootfs/opt/lxd/lib"
mkdir -p "${tmpdir}/rootfs/usr/local/bin"

cp ~/go/bin/* "${tmpdir}/rootfs/opt/lxd/bin"
cp "${vendor}/dqlite/.libs/libdqlite.so"* "${tmpdir}/rootfs/opt/lxd/lib"
cp "${vendor}/raft/.libs/libraft.so"* "${tmpdir}/rootfs/opt/lxd/lib"
if [ -d "${vendor}/sqlite" ]; then
	cp "${vendor}/sqlite/.libs/libsqlite3.so"* "${tmpdir}/rootfs/opt/lxd/lib"
fi
if [ -d "${vendor}/libco" ]; then
	cp "${vendor}/libco/libco.so"*  "${tmpdir}/rootfs/opt/lxd/lib"
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
