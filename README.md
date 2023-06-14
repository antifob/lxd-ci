# lxd builds

This repository serves to build tarballs of LXD using GitHub Actions
and GitLab's CI. Current targets are:

- Debian bullseye
- Debian bookworm
- Debian sid

Feel free to share a patch for other distributions. :)


Note that I try to stay up to date with the latest version, but there
will be some delays at time.


## Downloading

### GitHub

The download a build from GitHub:

1. go to release on the right menu;
2. select the latest release;
3. download the tarball for your Linux distribution.

```
vers=5.1
dist=$(lsb_release -cs)

https://github.com/antifob/lxd-ci/releases/download/${vers}/lxd-${vers}-${dist}.tar.gz
```

### GitLab (no longer maintained)

To download a build from GitLab:

1. go to `Pipeline` in the left menu;
2. select the latest successful build (marked _passed_);
3. select the target Linux distribution;
4. select `Browse` in the right menu;
5. select the tarball;
6. either click the link to download or copy it to your favorite tool.

Or use the following URL scheme:

```
vers=5.1
dist=$(lsb_release -cs)

https://gitlab.com/pgregoire-ci/lxd/-/jobs/artifacts/v${vers}/raw/lxd-${vers}-${dist}.tar.gz?job=${dist}
```


## Install

Packaging is done to overwrite no files. Integration must be done by the
administrator.

```
# assuming version 5.1 and Debian bullseye, running as root

gzip -cd lxd-5.1.bullseye.tar.gz | (cd / && tar -f- -x)

ln -s /opt/lxd-5.1/bin/lxc /usr/local/bin/lxc
ln -s /opt/lxd-5.1/bin/lxd /usr/local/bin/lxd

# systemd services
cp /opt/lxd-5.1/etc/lxd.service /etc/systemd/system/
cp /opt/lxd-5.1/etc/lxd-containers.service /etc/systemd/system/
cp /opt/lxd-5.1/etc/lxd.socket /etc/systemd/system/
systemctl daemon-reload

# see the bin/ and etc/ directory for more files
```


## Update cycle

The CI is triggered on tags. When a new version of LXD is published, it
is simply a matter of creating and pushing a matching tag. Note that the
build dependencies and steps are pretty stable. If the job fails, check
if a newer Go version is required and update the jobs accordingly.

```
# a new version of LXD was released (tag: lxd-a.b)
# build a specific branch or commit (tag: master)
git tag $ref
git push --tags
```



## References

https://github.com/lxc/lxd
