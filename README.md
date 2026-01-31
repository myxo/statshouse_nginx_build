# nginx-statshouse-module build

Builds the VKCOM statshouse nginx module against a specific nginx version and
produces a Debian 12 compatible `.so` artifact.

## Local build

Dependencies (Debian 12):

```
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl git libpcre2-dev libssl-dev zlib1g-dev
```

Run:

```
NGINX_VERSION=1.29.4 bash ./build.sh
```

Output:

- `dist/ngx_http_statshouse_module_<nginx>_<arch>.so`
- `dist/ngx_http_statshouse_module_<nginx>_<arch>.so.buildinfo`
- `dist/ngx_http_statshouse_module_<nginx>_<arch>.so.sha256` (if `sha256sum` is available)

## GitHub Actions

On push to `master` or tag `v*`, the workflow builds for `amd64` and `arm64`.
On tag `v*`, it also creates a GitHub release and uploads the artifacts.
