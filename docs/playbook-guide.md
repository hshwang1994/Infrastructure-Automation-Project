# Playbook 작성 가이드

## 기본 구조

```yaml
- name: 작업명
  hosts: all
  gather_facts: true/false
  connection: ssh/winrm/local

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/타입.yml"

  tasks:
    - name: 작업 실행
      ...
```

## 서버 타입별 기준

| target_type | connection | gather_facts | vault 파일 |
|------------|-----------|--------------|-----------|
| linux | ssh | true (운영) / false (OS 설치 전) | vault/linux.yml |
| windows | winrm | true (운영) / false (OS 설치 전) | vault/windows.yml |
| esxi | ssh | true (운영) / false (OS 설치 전) | vault/esxi.yml |
| redfish | local | false — BMC 접속이므로 OS Fact 수집 불가 | vault/redfish/{vendor}.yml |

## inventory_hostname 규칙

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | `bmc_ip` 값 | `bmc_ip` 값 |
| linux / windows / esxi | `hostname` 값 | `service_ip` 값 |

## hostvars 참조

```yaml
# ── linux / windows / esxi ──────────────────────────────
# inventory_hostname = hostname 값 (예: WEB-01)
hostvars[inventory_hostname]['ansible_host']   # service_ip (실제 접속 IP)
hostvars[inventory_hostname]['bmc_ip']         # BMC IP (있으면)
hostvars[inventory_hostname]['vendor']         # BMC 벤더 (있으면)

# ── redfish ──────────────────────────────────────────────
# inventory_hostname = bmc_ip 값 (예: 10.0.1.1)
hostvars[inventory_hostname]['ansible_host']   # bmc_ip (실제 접속 IP)
hostvars[inventory_hostname]['service_ip']     # OS IP (있으면)
hostvars[inventory_hostname]['hostname']       # 호스트명 (있으면)
hostvars[inventory_hostname]['vendor']         # BMC 벤더 (있으면)
```

## 공통 변수 패턴

모든 playbook 에서 아래 변수를 선언하면 로그 출력 시 일관성을 유지할 수 있다.

```yaml
vars:
  _host: "{{ inventory_hostname }}"
  _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] | default(inventory_hostname) }}"
```
