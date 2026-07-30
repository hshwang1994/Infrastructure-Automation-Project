#!/usr/bin/env python3
import json
import os
import sys


def error(msg):
    print(f"[example/inventory] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load_inventory_json():
    raw = os.environ.get("INVENTORY_JSON", "").strip()
    if not raw:
        error("INVENTORY_JSON 환경변수가 비어있습니다.")
    return raw


def get_field(host, field, idx, required=False):
    value = str(host.get(field, "")).strip()
    if required and not value:
        error(f"항목[{idx}] 에 '{field}' 필드가 필수인데 비어있습니다: {host}")
    return value


def parse_host(host, idx):
    hostname = get_field(host, "hostname", idx) or get_field(host, "hostName", idx, required=True)
    ansible_host = get_field(host, "ansible_host", idx) or get_field(host, "service_ip", idx) or hostname

    key = hostname
    host_vars = {"ansible_host": ansible_host}

    exclude = ("hostname", "hostName", "ansible_host", "service_ip")
    host_vars.update({k: v for k, v in host.items() if k not in exclude and v is not None})

    return key, host_vars


def build_inventory(payload):
    host_keys = []
    hostvars = {}
    seen = set()

    for idx, host in enumerate(payload):
        key, host_vars = parse_host(host, idx)
        if key in seen:
            error(f"inventory_hostname 이 중복됩니다: '{key}' (항목[{idx}])")
        seen.add(key)
        host_keys.append(key)
        hostvars[key] = host_vars

    return {"all": {"hosts": host_keys}, "_meta": {"hostvars": hostvars}}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
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

    print(json.dumps(build_inventory(payload), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
