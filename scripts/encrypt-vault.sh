#!/usr/bin/env bash
# credentials/*.yml (평문) → vault/*.yml (ansible-vault 암호화) 일괄 변환
#
# 사용법:
#   ./scripts/encrypt-vault.sh              # 모든 파일
#   ./scripts/encrypt-vault.sh linux        # 특정 target_type 만
#
# 비밀번호 입력 방식:
#   1. 환경변수 ANSIBLE_VAULT_PASSWORD 가 있으면 사용
#   2. 환경변수 ANSIBLE_VAULT_PASSWORD_FILE 가 가리키는 파일에서 읽음
#   3. 둘 다 없으면 인터랙티브 입력 (--ask-vault-pass)
#
# ansible-vault 위치:
#   PATH 에 있으면 그걸 사용, 없으면 /opt/ansible-env/bin/ansible-vault 시도.
#   둘 다 없으면 ANSIBLE_VAULT_BIN 환경변수로 override 가능.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRED_DIR="${REPO_ROOT}/credentials"
VAULT_DIR="${REPO_ROOT}/vault"

# 어떤 type 처리할지 결정
if [[ $# -gt 0 ]]; then
  TYPES=("$@")
else
  TYPES=(linux windows esxi redfish)
fi

# ansible-vault 위치 찾기 (override > PATH > venv 표준 경로)
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

# 비밀번호 옵션 결정
VAULT_OPT=()
if [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
  TMP_PW_FILE="$(mktemp)"
  trap 'rm -f "${TMP_PW_FILE}"' EXIT
  printf '%s' "${ANSIBLE_VAULT_PASSWORD}" > "${TMP_PW_FILE}"
  VAULT_OPT=(--vault-password-file "${TMP_PW_FILE}")
elif [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
  VAULT_OPT=(--vault-password-file "${ANSIBLE_VAULT_PASSWORD_FILE}")
else
  VAULT_OPT=(--ask-vault-pass)
fi

mkdir -p "${VAULT_DIR}"

for t in "${TYPES[@]}"; do
  SRC="${CRED_DIR}/${t}.yml"
  DST="${VAULT_DIR}/${t}.yml"

  if [[ ! -f "${SRC}" ]]; then
    echo "skip ${t} — ${SRC} 가 없습니다." >&2
    continue
  fi

  echo "encrypt ${SRC} -> ${DST}"
  "${ANSIBLE_VAULT_BIN}" encrypt "${SRC}" "${VAULT_OPT[@]}" --output "${DST}"
done

echo "완료. vault/*.yml 을 commit 하세요."
