#!/bin/sh
##
set -eu

apt-get -y install \
    acl \
    autoconf \
    dnsmasq-base \
    git \
    golang \
    libacl1-dev \
    libcap-dev \
    liblxc1 \
    lxc-dev \
    libtool \
    libuv1-dev \
    make \
    pkg-config \
    rsync \
    squashfs-tools \
    tar \
    tcl \
    xz-utils \
    ebtables
    
tmpdir=$(mktemp -d)
export GOPATH="${tmpdir}"

go get -d -v github.com/lxc/lxd/lxd || :
cd "${GOPATH}/src/github.com/lxc/lxd"
make deps
# TODO exports
make

mkdir -p "${tmpdir}/opt/lxd/bin"
mkdir -p "${tmpdir}/opt/lxd/lib"
mkdir -p "${tmpdir}/usr/local/bin"

cp "${GOPATH}"/bin/* "${tmpdir}/opt/lxd/bin"
cp "${GOPATH}"/deps/sqlite/.libs/libsqlite.so* "${tmpdir}/opt/lxd/lib"
cp "${GOPATH}"/deps/libco/libco.so "${tmpdir}/opt/lxd/lib"
cp "${GOPATH}"/deps/raft/.libs/libraft.so* "${tmpdir}/opt/lxd/lib"
cp "${GOPATH}"/deps/sqlite/.libs/libsqlite3.so* "${tmpdir}/opt/lxd/lib"
cp ./bin.lxc "${tmpdir}/usr/local/bin/lxc"
cp ./bin/lxd "${tmpdir}/usr/local/bin/lxd"

(cd "${tmpdir}" && tar -f- -c opt usr) | gzip -9c >./lxd.tar.gz