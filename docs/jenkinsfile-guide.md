# Jenkinsfile 작성 가이드

## 기본 골격

모든 Jenkinsfile 은 아래 구조를 기본으로 한다.
`loc`, `target_type`, `inventory_json` 은 포털이 전달하는 예약 파라미터이므로
`defaultValue` 는 빈 값으로 유지한다.

```groovy
pipeline {
    agent { label "${params.loc}" }

    parameters {
        // 포털 전달: Agent 위치 (ich | chj | yi)
        string(name: 'loc', defaultValue: '', description: '포털 전달: Agent 위치')

        // 포털 전달: 대상 종류 (linux | windows | esxi | redfish)
        string(name: 'target_type', defaultValue: '', description: '포털 전달: 대상 종류')

        // 포털 전달: 타겟 호스트 JSON 배열
        // defaultValue 는 포털이 jspreadsheet 컬럼 정의로 사용한다.
        text(
            name        : 'inventory_json',
            defaultValue: '''[
  {
    "bmc_ip": "",
    "service_ip": "",
    "hostname": "",
    "vendor": ""
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
        stage('Run Ansible') {
            steps {
                ansiblePlaybook(
                    playbook : "${WORKSPACE}/playbooks/작업경로/site.yml",
                    inventory: "${WORKSPACE}/inventory/my_inventory.sh",
                    colorized: true
                )
            }
        }
    }
}
```

## 예약 파라미터 (3개 필수)

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `loc` | string | 포털이 전달하는 Agent 위치 (ich \| chj \| yi) |
| `target_type` | string | 포털이 전달하는 대상 종류 (linux \| windows \| esxi \| redfish) |
| `inventory_json` | text | 포털이 전달하는 타겟 호스트 JSON 배열 |

## inventory_json 설계 원칙

인벤토리 스크립트는 **"라우터"** 역할만 한다.
`TARGET_TYPE` 을 보고 `inventory_hostname` / `ansible_host` 를 결정하고,
나머지 필드는 이름이 뭐든 값이 뭐든 그대로 `hostvars` 에 전달한다.

포털은 작업에 따라 어떤 필드든 자유롭게 추가할 수 있으며,
인벤토리 스크립트가 그 필드를 알 필요 없이 playbook 에서 직접 참조한다.

### 인벤토리 스크립트가 사용하는 필드 (3개만)

| 필드 | 사용 조건 | 역할 |
|------|----------|------|
| `bmc_ip` | target_type == redfish 일 때 필수 | inventory_hostname + ansible_host |
| `service_ip` | target_type != redfish 일 때 필수 | ansible_host |
| `hostname` | target_type != redfish 일 때 필수 | inventory_hostname |

이 3개 외의 모든 필드는 인벤토리 스크립트가 해석하지 않고 `hostvars` 에 그대로 통과시킨다.

### 포털이 보내는 필드

포털은 작업에 따라 자유롭게 필드를 구성한다.
기본 4개(bmc_ip, service_ip, hostname, vendor) 중에서도 해당 작업에 필요 없으면 안 보낼 수 있다.

**예시 — Linux 서비스 점검:**
```json
[
  {"service_ip": "10.0.2.1", "hostname": "WEB-01"},
  {"service_ip": "10.0.2.2", "hostname": "WEB-02"}
]
```

**예시 — Redfish 펌웨어 확인:**
```json
[
  {"bmc_ip": "10.0.1.1", "vendor": "dell"},
  {"bmc_ip": "10.0.1.2", "vendor": "hpe"}
]
```

**예시 — BMC 통한 OS 설치 (확장 필드 다수):**
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

## REPO_ROOT 환경변수

`REPO_ROOT = "${WORKSPACE}"` 로 선언하면 `site.yml` 에서 vault 경로를 아래처럼 참조할 수 있다.

```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
```

`WORKSPACE` 는 Jenkins 런타임 변수라 `/etc/ansible/ansible.cfg` 에 넣을 수 없으므로
Jenkinsfile `environment` 블록에서 선언한다.
