#!/usr/bin/env python3
"""
동적 인벤토리 스크립트

환경변수 INVENTORY_JSON 또는 .inventory_input.json 파일을 읽어
Ansible 호환 인벤토리 JSON 을 stdout 으로 출력한다.

환경변수:
  INVENTORY_JSON  — 포털이 전달하는 호스트 배열 (JSON 문자열)
  TARGET_TYPE     — 대상 종류 (linux | windows | esxi | redfish)

입력 우선순위:
  1. 환경변수 INVENTORY_JSON (값이 있으면 사용)
  2. WORKSPACE/.inventory_input.json 파일 (Jenkinsfile writeFile 로 생성)
  3. 둘 다 없으면 에러

inventory_hostname 결정 규칙 (TARGET_TYPE 기반):
  - redfish  → inventory_hostname = bmc_ip,      ansible_host = bmc_ip
  - 그 외    → inventory_hostname = hostname,     ansible_host = service_ip

기본 필드 (4개):
  bmc_ip      — BMC 관리 IP (redfish 필수)
  service_ip  — OS 서비스 IP (linux/windows/esxi 필수)
  hostname    — 호스트명 (linux/windows/esxi 필수)
  vendor      — BMC 벤더 (선택)

  이 외의 필드는 작업별로 자유롭게 추가 가능하며,
  모두 hostvars 에 그대로 전달된다.

INVENTORY_JSON 형식:
  [
    {
      "bmc_ip":     "10.0.1.1",
      "service_ip": "10.0.2.1",
      "hostname":   "WEB-01",
      "vendor":     "dell"
    }
  ]
"""

import ipaddress
import json
import os
import pathlib
import sys

# ── 기본 필드 정의 ──────────────────────────────────────────────────
BASE_FIELDS = ("bmc_ip", "service_ip", "hostname", "vendor")


# ── 유틸리티 ────────────────────────────────────────────────────────

def error(msg: str) -> None:
    """에러 메시지를 stderr 에 출력하고 종료한다."""
    print(f"[my_inventory] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def validate_ip(value: str, field_name: str, idx: int) -> None:
    """IP 주소 형식을 검증한다. 유효하지 않으면 에러로 종료."""
    try:
        ipaddress.ip_address(value)
    except ValueError:
        error(f"항목[{idx}] '{field_name}' 값이 유효하지 않은 IP 주소입니다: {value}")


def get_field(host: dict, field: str, idx: int, required: bool = False) -> str:
    """호스트 dict 에서 필드 값을 꺼낸다. required=True 면 없을 시 에러."""
    value = host.get(field, "").strip()
    if required and not value:
        error(f"항목[{idx}]에 '{field}' 필드가 필수인데 비어있습니다: {host}")
    return value


# ── 입력 로딩 ───────────────────────────────────────────────────────

def load_target_type() -> str:
    """환경변수에서 TARGET_TYPE 을 읽는다."""
    target_type = os.environ.get("TARGET_TYPE", "").strip().lower()
    if not target_type:
        target_type = os.environ.get("target_type", "").strip().lower()
    if not target_type:
        error("TARGET_TYPE 환경변수가 설정되지 않았습니다.")
    return target_type


def load_inventory_json() -> str:
    """환경변수 → 파일 순서로 인벤토리 JSON 문자열을 가져온다."""
    # 1순위: 환경변수 (대문자 또는 소문자 — Jenkins 파라미터명 그대로 내보내짐)
    raw = os.environ.get("INVENTORY_JSON", "").strip()
    if not raw:
        raw = os.environ.get("inventory_json", "").strip()
    if raw:
        return raw

    # 2순위: .inventory_input.json 파일
    workspace = os.environ.get("WORKSPACE", "")
    if workspace:
        fallback = pathlib.Path(workspace) / ".inventory_input.json"
    else:
        fallback = pathlib.Path(__file__).resolve().parent.parent / ".inventory_input.json"

    if fallback.is_file():
        content = fallback.read_text(encoding="utf-8").strip()
        if content:
            return content

    error("INVENTORY_JSON 환경변수와 .inventory_input.json 파일 모두 비어있습니다.")


# ── 호스트 파싱 ─────────────────────────────────────────────────────

def parse_host_redfish(host: dict, idx: int) -> tuple:
    """redfish 호스트를 파싱한다. (inventory_hostname = bmc_ip)"""
    bmc_ip = get_field(host, "bmc_ip", idx, required=True)
    validate_ip(bmc_ip, "bmc_ip", idx)

    key = bmc_ip
    host_vars = {"ansible_host": bmc_ip}

    # 선택 필드: service_ip 가 있으면 검증 후 포함
    service_ip = get_field(host, "service_ip", idx)
    if service_ip:
        validate_ip(service_ip, "service_ip", idx)

    # 기본 필드 외 모든 필드를 hostvars 에 전달 (bmc_ip 제외 — 이미 ansible_host)
    for field, value in host.items():
        if field != "bmc_ip" and value:
            host_vars[field] = value

    return key, host_vars


def parse_host_os(host: dict, idx: int) -> tuple:
    """linux/windows/esxi 호스트를 파싱한다. (inventory_hostname = hostname)"""
    hostname = get_field(host, "hostname", idx, required=True)
    service_ip = get_field(host, "service_ip", idx, required=True)
    validate_ip(service_ip, "service_ip", idx)

    key = hostname
    host_vars = {"ansible_host": service_ip}

    # 선택 필드: bmc_ip 가 있으면 검증 후 포함
    bmc_ip = get_field(host, "bmc_ip", idx)
    if bmc_ip:
        validate_ip(bmc_ip, "bmc_ip", idx)

    # 기본 필드 외 모든 필드를 hostvars 에 전달 (hostname, service_ip 제외)
    for field, value in host.items():
        if field not in ("hostname", "service_ip") and value:
            host_vars[field] = value

    return key, host_vars


# ── 인벤토리 빌드 ───────────────────────────────────────────────────

def build_inventory(payload: list, target_type: str) -> dict:
    """호스트 배열을 Ansible 인벤토리 dict 로 변환한다."""
    host_keys = []
    hostvars = {}
    seen_keys = set()

    parser = parse_host_redfish if target_type == "redfish" else parse_host_os

    for idx, host in enumerate(payload):
        key, host_vars = parser(host, idx)

        if key in seen_keys:
            error(f"inventory_hostname 이 중복됩니다: '{key}' (항목[{idx}])")
        seen_keys.add(key)

        host_keys.append(key)
        hostvars[key] = host_vars

    return {
        "all": {"hosts": host_keys},
        "_meta": {"hostvars": hostvars},
    }


# ── 메인 ────────────────────────────────────────────────────────────

def main() -> None:
    # --host 인자 처리 (Ansible 동적 인벤토리 규약)
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        print("{}")
        return

    target_type = load_target_type()
    raw = load_inventory_json()

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        error(f"INVENTORY_JSON 파싱 실패: {e}")

    if not isinstance(payload, list):
        error("INVENTORY_JSON 최상위는 배열이어야 합니다.")

    if not payload:
        error("INVENTORY_JSON 배열이 비어있습니다.")

    inventory = build_inventory(payload, target_type)
    print(json.dumps(inventory, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
