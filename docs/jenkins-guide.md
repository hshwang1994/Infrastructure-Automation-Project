# Jenkinsfile 작성 가이드

## 기본 골격

모든 Jenkinsfile 은 아래 구조를 기본으로 한다.
`loc` 과 `target_type` 은 포털이 전달하는 값이므로 `defaultValue` 는 빈 값으로 유지한다.

```groovy
pipeline {
    agent { label "${params.loc}" }

    parameters {
        // 포털이 전달하는 실행 대상 로케이션 (슬레이브 Labels: ich | chj | yi)
        string(name: 'loc',         defaultValue: '', description: 'Location')

        // 포털이 전달하는 대상 종류
        string(name: 'target_type', defaultValue: '', description: '대상 종류')

        // defaultValue 는 포털이 jspreadsheet 컬럼 정의로 사용한다.
        text(
            name        : 'inventory_json',
            defaultValue: '''[
  {
    "ip": "",
    "hostname": ""
  }
]''',
            description : '포털에서 전달하는 타겟 호스트 JSON'
        )
    }

    environment {
        INVENTORY_JSON = "${params.inventory_json}"
        REPO_ROOT      = "${WORKSPACE}"
    }

    stages {
        stage('Run Ansible') {
            steps {
                ansiblePlaybook(
                    playbook : "${WORKSPACE}/playbooks/작업명/타입/site.yml",
                    inventory: "${WORKSPACE}/inventory/my_inventory.sh",
                    colorized: true
                )
            }
        }
    }
}
```

## inventory_json 필드 규칙

| 필드 | 필수 여부 | 설명 |
|------|----------|------|
| `ip` | 필수 | Ansible 접속 IP |
| `hostname` | linux/windows/esxi 필수 | Ansible inventory_hostname. 결과 로그에 표시됨 |
| `vendor` | redfish 필수 | BMC 벤더 (lenovo / dell / hp) |
| `service_ip` | os-provisioning 필수 | 포털 후속 Job 연계용 — 제거 금지 |
| `os_hostname` | os-provisioning 필수 | OS 내부에 적용할 hostname (통신과 무관) |
| `firmware_version` | firmware-update 선택 | 미입력 시 최신 버전으로 업데이트 |

## REPO_ROOT 환경변수

`REPO_ROOT = "${WORKSPACE}"` 로 선언하면 `site.yml` 에서 vault 경로를 아래처럼 참조할 수 있다.

```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
```

`WORKSPACE` 는 Jenkins 런타임 변수라 `/etc/ansible/ansible.cfg` 에 넣을 수 없으므로
Jenkinsfile `environment` 블록에서 선언한다.
