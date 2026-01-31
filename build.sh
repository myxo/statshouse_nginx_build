#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd -P)"
NGINX_VERSION="${NGINX_VERSION:-1.29.4}"
MODULE_REPO="${MODULE_REPO:-https://github.com/VKCOM/nginx-statshouse-module.git}"
MODULE_REF="${MODULE_REF:-}"
OUT_DIR="${OUT_DIR:-dist}"
WORK_DIR="${WORK_DIR:-}"

if [[ -z "${WORK_DIR}" ]]; then
  WORK_DIR="$(mktemp -d)"
  CLEAN_WORKDIR=1
else
  mkdir -p "${WORK_DIR}"
  CLEAN_WORKDIR=0
fi

cleanup() {
  if [[ "${CLEAN_WORKDIR}" -eq 1 ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

for cmd in curl tar git make; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "missing required command: ${cmd}" >&2
    exit 1
  fi
done

ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "unsupported architecture: ${ARCH_RAW}" >&2
    exit 1
    ;;
esac

if [[ "${OUT_DIR}" = /* ]]; then
  OUT_DIR_ABS="${OUT_DIR}"
else
  OUT_DIR_ABS="${ROOT_DIR}/${OUT_DIR}"
fi
mkdir -p "${OUT_DIR_ABS}"

MODULE_DIR="${WORK_DIR}/nginx-statshouse-module"
NGINX_TARBALL="nginx-${NGINX_VERSION}.tar.gz"
NGINX_URL="https://nginx.org/download/${NGINX_TARBALL}"

git clone --depth 1 "${MODULE_REPO}" "${MODULE_DIR}"
if [[ -n "${MODULE_REF}" ]]; then
  git -C "${MODULE_DIR}" fetch --depth 1 origin "${MODULE_REF}"
  git -C "${MODULE_DIR}" checkout FETCH_HEAD
fi
MODULE_COMMIT="$(git -C "${MODULE_DIR}" rev-parse --short=12 HEAD)"

curl -fsSL -o "${WORK_DIR}/${NGINX_TARBALL}" "${NGINX_URL}"
tar -xzf "${WORK_DIR}/${NGINX_TARBALL}" -C "${WORK_DIR}"

pushd "${WORK_DIR}/nginx-${NGINX_VERSION}" >/dev/null
./configure \
  --with-compat \
  --add-dynamic-module="${MODULE_DIR}"

make -j"$(getconf _NPROCESSORS_ONLN)" modules

MODULE_SO=""
if compgen -G "objs/*statshouse*.so" > /dev/null; then
  MODULE_SO="$(ls objs/*statshouse*.so | head -n1)"
elif compgen -G "objs/*.so" > /dev/null; then
  MODULE_SO="$(ls objs/*.so | head -n1)"
fi

if [[ -z "${MODULE_SO}" || ! -f "${MODULE_SO}" ]]; then
  echo "module .so not found in objs/" >&2
  exit 1
fi

OUT_NAME="ngx_http_statshouse_module_${NGINX_VERSION}_${ARCH}.so"
cp "${MODULE_SO}" "${OUT_DIR_ABS}/${OUT_NAME}"

cat > "${OUT_DIR_ABS}/${OUT_NAME}.buildinfo" <<EOF
nginx_version=${NGINX_VERSION}
module_repo=${MODULE_REPO}
module_ref=${MODULE_REF:-default}
module_commit=${MODULE_COMMIT}
arch=${ARCH_RAW}
EOF

if command -v sha256sum >/dev/null 2>&1; then
  (cd "${OUT_DIR_ABS}" && sha256sum "${OUT_NAME}" > "${OUT_NAME}.sha256")
fi
popd >/dev/null

echo "built ${OUT_DIR_ABS}/${OUT_NAME}"
