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

## inventory_json 필드 규칙

### 기본 필드 (4개)

| 필드 | redfish | linux/windows/esxi | 설명 |
|------|---------|-------------------|------|
| `bmc_ip` | **필수** | 선택 | BMC 관리 IP |
| `service_ip` | 선택 | **필수** | OS 서비스 IP (SSH/WinRM 접속) |
| `hostname` | 선택 | **필수** | 호스트명 (Ansible 결과 로그에 표시) |
| `vendor` | 선택 | 선택 | BMC 벤더 (dell \| hpe \| lenovo \| supermicro) |

### 확장 필드

기본 4개 외의 필드는 작업별로 자유롭게 추가할 수 있다.
포털에서 전달하지 않은 필드는 인벤토리 스크립트가 무시한다.

예: OS 설치 작업에서 추가 필드가 필요한 경우
```json
[
  {
    "bmc_ip": "10.0.1.1",
    "service_ip": "10.0.2.1",
    "hostname": "WEB-01",
    "vendor": "dell",
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
