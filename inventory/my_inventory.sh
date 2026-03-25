#!/usr/bin/env python3
"""
동적 인벤토리 스크립트

환경변수 INVENTORY_JSON 또는 .inventory_input.json 파일을 읽어
Ansible 호환 인벤토리 JSON 을 stdout 으로 출력한다.

우선순위:
  1. 환경변수 INVENTORY_JSON (값이 있으면 사용)
  2. 스크립트와 같은 workspace의 .inventory_input.json 파일
  3. 둘 다 없으면 에러

hostname 필드 유무에 따라 inventory_hostname 이 달라진다:
  - hostname 있음 → inventory_hostname = hostname, ansible_host = ip
    예: Linux / Windows / ESXi — Ansible 결과가 호스트명으로 표시됨
  - hostname 없음 → inventory_hostname = ip
    예: Redfish (BMC) — 호스트명 개념이 없으므로 IP 그대로 사용

INVENTORY_JSON 형식:
  [
    {
      "ip":          "10.x.x.1",    # 필수: Ansible 접속 IP
      "hostname":    "WEB-01",      # 선택: 있으면 inventory_hostname 으로 사용
      "os_hostname": "linux01",     # OS 내부에 적용할 hostname (통신과 무관)
      "service_ip":  "10.x.x.100", # 포털 후속 Job 연계용 (os-provisioning 전용)
      "vendor":      "lenovo"       # redfish 작업 시 벤더 구분
    }
  ]
"""

import ipaddress
import json
import os
import pathlib
import sys


def error(msg: str) -> None:
    print(f"[my_inventory] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def validate_ip(ip: str) -> None:
    """IP 주소 형식을 검증한다."""
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        error(f"유효하지 않은 IP 주소입니다: {ip}")


def load_inventory_json() -> str:
    """환경변수 → 파일 순서로 인벤토리 JSON 문자열을 가져온다."""
    # 1순위: 환경변수 (대문자 또는 소문자 — Jenkins 파라미터명 그대로 내보내짐)
    raw = os.environ.get("INVENTORY_JSON", "").strip()
    if not raw:
        raw = os.environ.get("inventory_json", "").strip()
    if raw:
        return raw

    # 2순위: .inventory_input.json 파일 (Jenkinsfile writeFile 로 생성됨)
    workspace = os.environ.get("WORKSPACE", "")
    if workspace:
        fallback = pathlib.Path(workspace) / ".inventory_input.json"
    else:
        # WORKSPACE 가 없으면 스크립트 위치 기준으로 상위 디렉토리 탐색
        fallback = pathlib.Path(__file__).resolve().parent.parent / ".inventory_input.json"

    if fallback.is_file():
        content = fallback.read_text(encoding="utf-8").strip()
        if content:
            return content

    error("INVENTORY_JSON 환경변수와 .inventory_input.json 파일 모두 비어있습니다.")


def main() -> None:
    # --list / --host 인자 처리 (Ansible 동적 인벤토리 규약)
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        # _meta 를 제공하므로 --host 호출 시 빈 dict 반환
        print("{}")
        return

    raw = load_inventory_json()

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        error(f"INVENTORY_JSON 파싱 실패: {e}")

    if not isinstance(payload, list):
        error("INVENTORY_JSON 최상위는 배열이어야 합니다.")

    if not payload:
        error("INVENTORY_JSON 배열이 비어있습니다.")

    hostvars = {}
    host_keys = []
    seen_keys = set()

    for idx, host in enumerate(payload):
        ip = host.get("ip", "").strip()
        if not ip:
            error(f"항목[{idx}]에 'ip' 필드가 없습니다: {host}")

        validate_ip(ip)

        hostname = host.get("hostname", "").strip()

        if hostname:
            # hostname 있음 → inventory_hostname = hostname, ansible_host = ip
            key = hostname
            vars_ = {"ansible_host": ip}
            vars_.update({k: v for k, v in host.items() if k not in ("ip", "hostname")})
        else:
            # hostname 없음 (redfish 등) → inventory_hostname = ip
            key = ip
            vars_ = {k: v for k, v in host.items() if k != "ip"}

        # 중복 검사
        if key in seen_keys:
            error(f"inventory_hostname 이 중복됩니다: '{key}' (항목[{idx}])")
        seen_keys.add(key)

        host_keys.append(key)
        hostvars[key] = vars_

    inventory = {
        "all": {"hosts": host_keys},
        "_meta": {"hostvars": hostvars}
    }

    print(json.dumps(inventory, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
