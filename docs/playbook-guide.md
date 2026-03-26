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

인벤토리 스크립트는 포털이 보낸 모든 필드를 `hostvars` 에 그대로 전달한다.
기본 3개(bmc_ip/service_ip/hostname) 외의 필드도 `hostvars[inventory_hostname]['필드명']` 으로 참조할 수 있다.

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

# ── 확장 필드 (포털이 추가로 보낸 것) ────────────────────
hostvars[inventory_hostname]['mgmt_ip']        # 관리 IP (있으면)
hostvars[inventory_hostname]['storage_ip']     # 스토리지 IP (있으면)
hostvars[inventory_hostname]['os_image']       # OS 이미지 (있으면)
# ... 포털이 보낸 모든 필드를 이 방식으로 참조
```

## 공통 변수 패턴

모든 playbook 에서 아래 변수를 선언하면 로그 출력 시 일관성을 유지할 수 있다.

```yaml
vars:
  _host: "{{ inventory_hostname }}"
  _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] | default(inventory_hostname) }}"
```

## 확장 필드 사용 예시 — BMC 통한 OS 설치

포털이 아래 JSON 을 전달하는 경우:
```json
[
  {
    "bmc_ip": "10.0.1.1",
    "service_ip": "10.0.2.1",
    "hostname": "WEB-01",
    "vendor": "dell",
    "mgmt_ip": "10.0.3.1",
    "storage_ip": "10.0.4.1",
    "gateway": "10.0.2.254",
    "netmask": "255.255.255.0",
    "dns_servers": "8.8.8.8,8.8.4.4",
    "os_image": "rhel-9.2",
    "boot_mode": "uefi"
  }
]
```

Jenkinsfile (target_type = redfish):
```groovy
pipeline {
    agent { label "${params.loc}" }

    parameters {
        string(name: 'loc',         defaultValue: '', description: '포털 전달: Agent 위치')
        string(name: 'target_type', defaultValue: '', description: '포털 전달: 대상 종류')
        text(
            name        : 'inventory_json',
            defaultValue: '''[
  {
    "bmc_ip": "",
    "service_ip": "",
    "hostname": "",
    "vendor": "",
    "mgmt_ip": "",
    "storage_ip": "",
    "gateway": "",
    "netmask": "",
    "dns_servers": "",
    "os_image": "",
    "boot_mode": ""
  }
]''',
            description : '포털에서 전달하는 타겟 호스트 JSON'
        )
    }

    environment {
        INVENTORY_JSON = "${params.inventory_json}"
        TARGET_TYPE    = "${params.target_type}"
        REPO_ROOT      = "${WORKSPACE}"
    }

    stages {
        stage('OS Install via BMC') {
            steps {
                ansiblePlaybook(
                    playbook : "${WORKSPACE}/playbooks/day1/os-install/redfish/site.yml",
                    inventory: "${WORKSPACE}/inventory/my_inventory.sh",
                    colorized: true
                )
            }
        }
    }
}
```

Playbook (site.yml):
```yaml
---
- name: BMC 통한 OS 설치
  hosts: all
  gather_facts: false
  connection: local

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/redfish/{{ hostvars[inventory_hostname]['vendor'] }}.yml"

  vars:
    _bmc_ip:     "{{ inventory_hostname }}"
    _service_ip: "{{ hostvars[inventory_hostname]['service_ip'] }}"
    _hostname:   "{{ hostvars[inventory_hostname]['hostname'] }}"
    _vendor:     "{{ hostvars[inventory_hostname]['vendor'] }}"
    _mgmt_ip:    "{{ hostvars[inventory_hostname]['mgmt_ip'] | default('') }}"
    _storage_ip: "{{ hostvars[inventory_hostname]['storage_ip'] | default('') }}"
    _gateway:    "{{ hostvars[inventory_hostname]['gateway'] }}"
    _netmask:    "{{ hostvars[inventory_hostname]['netmask'] }}"
    _dns:        "{{ hostvars[inventory_hostname]['dns_servers'] }}"
    _os_image:   "{{ hostvars[inventory_hostname]['os_image'] }}"
    _boot_mode:  "{{ hostvars[inventory_hostname]['boot_mode'] | default('uefi') }}"

  tasks:
    - name: "os-install | BMC 접속 확인"
      ansible.builtin.uri:
        url: "https://{{ _bmc_ip }}/redfish/v1/"
        method: GET
        user: "{{ ansible_user }}"
        password: "{{ ansible_password }}"
        validate_certs: false
      register: _bmc_check

    - name: "os-install | OS 이미지 마운트"
      ansible.builtin.debug:
        msg: >-
          [{{ _bmc_ip }}] OS={{ _os_image }}, Boot={{ _boot_mode }}
          | Service IP: {{ _service_ip }}
          | Gateway: {{ _gateway }}, DNS: {{ _dns }}

    # ... 이후 실제 OS 설치 태스크
```
