#!/bin/sh
# usage: $0 version outfile
set -eux

origdir=$(pwd)

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

mkdir -p "${tmpdir}/rootfs/opt/lxd-${1}/bin"
mkdir    "${tmpdir}/rootfs/opt/lxd-${1}/lib"

cp ~/go/bin/* "${tmpdir}/rootfs/opt/lxd-${1}/bin"
cp "${vendor}/dqlite/.libs/libdqlite.so"* "${tmpdir}/rootfs/opt/lxd-${1}/lib"
cp "${vendor}/raft/.libs/libraft.so"* "${tmpdir}/rootfs/opt/lxd-${1}/lib"

cat >"${tmpdir}/rootfs/opt/lxd-${1}/bin/lxc.wrapper"<<__EOF__
#!/bin/sh
set -eu
export LD_LIBRARY_PATH=/opt/lxd-${1}/lib
exec /opt/lxd-${1}/bin/lxc "\${@}"
__EOF__

cat >"${tmpdir}/rootfs/opt/lxd-${1}/bin/lxd.wrapper"<<__EOF__
#!/bin/sh
set -eu
export PATH="/opt/lxd-${1}/bin:\${PATH}"
export LD_LIBRARY_PATH=/opt/lxd-${1}/lib
exec /opt/lxd-${1}/bin/lxd "\${@}"
__EOF__

chmod 0555 "${tmpdir}/rootfs/opt/lxd-${1}/bin"/*
chmod 0444 "${tmpdir}/rootfs/opt/lxd-${1}/lib"/*

cp -r "${origdir}/etc" "${tmpdir}/rootfs/opt/lxd-${1}"

(cd "${tmpdir}/rootfs" && tar --owner=root --group=root -f- -c .) | gzip -9c >"${2}"
