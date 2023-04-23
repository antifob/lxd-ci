#!/bin/sh
# usage: $0 gitref outfile
set -eux

origdir=$(pwd)

tmpdir=$(mktemp -d)
cleanup() {
	rm -rf "${tmpdir}"
}
trap cleanup EXIT INT QUIT TERM

B="${1}"
if echo "${B}" | grep -Eq '^[0-9]+[.]'; then
	B="lxd-${B}"
	printf '[+] Assuming gitref is a release tag (%s -> %s)\n' "${1}" "${B}"
fi

cd "${tmpdir}"
git clone --depth=1 -b "${B}" https://github.com/lxc/lxd
cd lxd

make deps

vendor="${HOME}/go/deps"
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
