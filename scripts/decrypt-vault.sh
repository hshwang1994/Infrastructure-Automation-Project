#!/usr/bin/env bash
# vault/*.yml (암호화) → credentials/*.yml (평문) 일괄 복호화
#
# 사용 시점: vault 비밀번호만 가진 사람이 평문 값을 확인/편집하려 할 때.
# 일반 워크플로우는 credentials/ 에서 편집 → encrypt-vault.sh 이므로
# 이 스크립트는 주로 디버깅/긴급 확인용.
#
# 사용법:
#   ./scripts/decrypt-vault.sh              # 모든 파일
#   ./scripts/decrypt-vault.sh linux        # 특정 target_type 만
#
# 비밀번호 / ansible-vault 위치 옵션: encrypt-vault.sh 와 동일.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRED_DIR="${REPO_ROOT}/credentials"
VAULT_DIR="${REPO_ROOT}/vault"

if [[ $# -gt 0 ]]; then
  TYPES=("$@")
else
  TYPES=(linux)
fi

ANSIBLE_VAULT_BIN="${ANSIBLE_VAULT_BIN:-}"
if [[ -z "${ANSIBLE_VAULT_BIN}" ]]; then
  if command -v ansible-vault &>/dev/null; then
    ANSIBLE_VAULT_BIN="$(command -v ansible-vault)"
  elif [[ -x /opt/ansible-env/bin/ansible-vault ]]; then
    ANSIBLE_VAULT_BIN="/opt/ansible-env/bin/ansible-vault"
  else
    echo "ERROR: ansible-vault 를 찾을 수 없습니다." >&2
    echo "  PATH 에 ansible-vault 가 있거나, /opt/ansible-env/bin/ansible-vault 가 존재해야 합니다." >&2
    echo "  또는 ANSIBLE_VAULT_BIN 환경변수로 경로를 지정하세요." >&2
    exit 1
  fi
fi

# 비밀번호 옵션 — ANSIBLE_VAULT_PASSWORD_FILE env 가 잡혀 있으면
# ansible-vault 가 자동으로 사용. CLI --vault-password-file 을 추가로 주면
# vault-id 중복으로 에러가 나므로 생략.
VAULT_OPT=()
if [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
  TMP_PW_FILE="$(mktemp)"
  trap 'rm -f "${TMP_PW_FILE}"' EXIT
  printf '%s' "${ANSIBLE_VAULT_PASSWORD}" > "${TMP_PW_FILE}"
  export ANSIBLE_VAULT_PASSWORD_FILE="${TMP_PW_FILE}"
elif [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
  : # ansible-vault 가 env 를 자동 사용
else
  VAULT_OPT=(--ask-vault-pass)
fi

mkdir -p "${CRED_DIR}"

for t in "${TYPES[@]}"; do
  SRC="${VAULT_DIR}/${t}.yml"
  DST="${CRED_DIR}/${t}.yml"

  if [[ ! -f "${SRC}" ]]; then
    echo "skip ${t} — ${SRC} 가 없습니다." >&2
    continue
  fi

  echo "decrypt ${SRC} -> ${DST}"
  "${ANSIBLE_VAULT_BIN}" decrypt "${SRC}" "${VAULT_OPT[@]}" --output "${DST}"
done

echo "완료. credentials/ 내용 확인하세요."
