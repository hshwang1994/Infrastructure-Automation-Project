# Jenkinsfile 작성 가이드

## 기본 골격

모든 Jenkinsfile 은 아래 구조를 기본으로 한다.
`loc`, `target_type`, `inventory_json` 은 포털이 전달하는 예약 파라미터이다.
`inventory_json` 의 `defaultValue` 는 **빈 배열 `[]`** 만 둔다.
실제 필드와 값은 포털이 서버 선택 시 전체를 채워서 전달하므로 Jenkinsfile 에서 스키마를 정의하지 않는다.

```groovy
pipeline {
    agent { label "${params.loc} && ${params.target_type}" }

    parameters {
        string(name: 'loc',         defaultValue: '', description: '포털 전달: Agent 위치 (ich | chj | yi)')
        string(name: 'target_type', defaultValue: '', description: '포털 전달: 대상 종류 (linux | windows | esxi | redfish)')
        text(
            name        : 'inventory_json',
            defaultValue: '[]',
            description : '포털 전달: 타겟 호스트 JSON 배열'
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
                withCredentials([
                    string(credentialsId: "ansible-${params.target_type}-user", variable: 'ANSIBLE_REMOTE_USER'),
                    string(credentialsId: "ansible-${params.target_type}-pass", variable: 'ANSIBLE_REMOTE_PASS')
                ]) {
                    ansiblePlaybook(
                        installation: 'ansible',
                        playbook    : "${WORKSPACE}/{작업경로}/site.yml",
                        extraVars   : [
                            ansible_user           : [value: "${ANSIBLE_REMOTE_USER}", hidden: true],
                            ansible_password       : [value: "${ANSIBLE_REMOTE_PASS}", hidden: true],
                            ansible_become_password: [value: "${ANSIBLE_REMOTE_PASS}", hidden: true]
                        ],
                        colorized: true
                    )
                }
            }
        }
    }
}
```

> `credentialsId` 가 `params.target_type` 으로 동적 선택된다 — `ansible-linux-*`, `ansible-windows-*`, `ansible-esxi-*`, `ansible-redfish-*`.
> `ansible_become_password` 는 linux 외 target_type 에서는 사용되지 않지만 extra 로 넘겨도 무해하므로 모든 타입에 동일하게 주입한다.
> 자격증명 ID 와 값 표준은 아래 [Jenkins Credentials](#jenkins-credentials-자격증명-주입) 섹션 참고.

## 예약 파라미터 (3개 필수)

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `loc` | string | 포털이 전달하는 Agent 위치 (ich \| chj \| yi) |
| `target_type` | string | 포털이 전달하는 대상 종류 (linux \| windows \| esxi \| redfish) |
| `inventory_json` | text | 포털이 전달하는 타겟 호스트 JSON 배열 |

## Jenkins Credentials (자격증명 주입)

서버 접속 계정은 **vault 파일이 아니라 Jenkins Credentials 에 저장**하고, `withCredentials` → `ansiblePlaybook(extraVars: ...)` 로 playbook 에 주입한다. `extraVars` 의 `hidden: true` 옵션이 콘솔 로그에서 값을 마스킹한다.

### 등록 절차

Jenkins → Manage Jenkins → Credentials → System → Global credentials → Add Credentials

- **Kind**: `Secret text`
- **Secret**: 실제 값 (사용자명 또는 비밀번호)
- **ID**: 아래 표의 ID 그대로 입력

### Credential ID 표준

**ID 네이밍 규칙:** `ansible-{target_type}-user` / `ansible-{target_type}-pass`

target_type 별로 **별도 ID** 를 유지한다 (운영 단계에서 계정 분리가 필요하기 때문). 현재는 사내 테스트 단계라 **모든 값을 `infra` / `infra1234` 로 통일**해 두지만, 향후 각 target_type 별 실제 운영 계정으로 교체될 수 있다.

| Credential ID | 종류 | 현재 값 | 향후 교체 예시 |
|---|---|---|---|
| `ansible-linux-user` / `ansible-linux-pass` | Secret Text | `infra` / `infra1234` | 운영 SSH 계정 |
| `ansible-windows-user` / `ansible-windows-pass` | Secret Text | `infra` / `infra1234` | 운영 도메인 계정 |
| `ansible-esxi-user` / `ansible-esxi-pass` | Secret Text | `infra` / `infra1234` | `root` 등 ESXi 계정 |
| `ansible-redfish-user` / `ansible-redfish-pass` | Secret Text | `infra` / `infra1234` | iDRAC / iLO 등 BMC 계정 |

각 `-user` 는 `ansible_user`, `-pass` 는 `ansible_password` (linux 는 추가로 `ansible_become_password`) 에 매핑된다.

> Redfish 는 현재 단일 ID 로 통일. 향후 vendor 별 계정 분리가 필요해지면 `ansible-redfish-{vendor}-user` 형태로 분기하고, Jenkinsfile 의 `credentialsId` 식을 `"ansible-redfish-${vendor}-user"` 로 바꾼다.

### Jenkinsfile 표준 패턴 (모든 target_type 공통)

`credentialsId` 가 `params.target_type` 으로 동적 선택되므로 **target_type 별 분기가 필요 없다.** 단일 stage 로 4가지 모두 처리 가능.

```groovy
stage('Run Ansible') {
    steps {
        withCredentials([
            string(credentialsId: "ansible-${params.target_type}-user", variable: 'U'),
            string(credentialsId: "ansible-${params.target_type}-pass", variable: 'P')
        ]) {
            ansiblePlaybook(
                installation: 'ansible',
                playbook    : "${WORKSPACE}/{작업경로}/site.yml",
                extraVars   : [
                    ansible_user           : [value: "${U}", hidden: true],
                    ansible_password       : [value: "${P}", hidden: true],
                    ansible_become_password: [value: "${P}", hidden: true]   // linux 외에는 사용 안 되지만 무해
                ],
                colorized: true
            )
        }
    }
}
```

> WinRM 연결 옵션(`ansible_winrm_transport` 등)은 시크릿이 아니므로 playbook 의 `vars` 블록에 둔다 ([`playbook-guide.md`](./playbook-guide.md) 의 windows 예시 참고).

### 마스킹 검증

`hidden: true` 가 적용되면 Jenkins 콘솔에 다음처럼 표시된다:
```
ansible-playbook ... -e ansible_user=**** -e ansible_password=****
```
실제 값이 노출되면 `extraVars` 의 `hidden` 설정이 누락된 것이다.

## inventory_json 구조

인벤토리 스크립트는 라우터 역할만 한다.
`TARGET_TYPE` 을 보고 `inventory_hostname` / `ansible_host` 를 결정하고,
나머지 필드는 그대로 `hostvars` 에 전달한다.

포털은 작업에 따라 필드를 자유롭게 추가할 수 있고,
playbook 에서 직접 참조한다.

### 인벤토리 스크립트가 사용하는 필드 (3개만)

| 필드 | 사용 조건 | 역할 |
|------|----------|------|
| `bmc_ip` | target_type == redfish 일 때 필수 | inventory_hostname + ansible_host |
| `service_ip` | target_type != redfish 일 때 필수 | ansible_host |
| `hostname` | target_type != redfish 일 때 필수 | inventory_hostname |

이 3개 외의 모든 필드는 인벤토리 스크립트가 해석하지 않고 `hostvars` 에 그대로 통과시킨다.

### 포털이 보내는 필드

Jenkinsfile `defaultValue` 는 빈 배열(`[]`) 이고, 필드 스키마는 포털이 작업별로 관리한다.
포털이 실제로 보내는 값은 작업에 따라 다르며, 필요 없는 필드는 빈 문자열로 들어와도 정상 동작한다.
"배열이다" 와 "필수 필드가 있다" 는 검증은 `my_inventory.sh` 가 수행한다.

**예시 — Linux 서비스 점검 (bmc_ip, vendor 는 빈 값):**
```json
[
  {"bmc_ip": "", "service_ip": "10.0.2.1", "hostname": "WEB-01", "vendor": ""},
  {"bmc_ip": "", "service_ip": "10.0.2.2", "hostname": "WEB-02", "vendor": ""}
]
```

**예시 — Redfish 펌웨어 확인 (service_ip, hostname 은 빈 값):**
```json
[
  {"bmc_ip": "10.0.1.1", "service_ip": "", "hostname": "", "vendor": "dell"},
  {"bmc_ip": "10.0.1.2", "service_ip": "", "hostname": "", "vendor": "hpe"}
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

`REPO_ROOT = "${WORKSPACE}"` 로 선언하면 playbook 에서 작업 저장소 루트 기준 상대경로를 안전하게 잡을 수 있다 (역할 파일, 템플릿, 스크립트 등).

```yaml
- ansible.builtin.copy:
    src: "{{ lookup('env', 'REPO_ROOT') }}/scripts/sample.sh"
    dest: /tmp/sample.sh
```

`WORKSPACE` 는 Jenkins 런타임 변수라 `/etc/ansible/ansible.cfg` 에 넣을 수 없으므로 Jenkinsfile `environment` 블록에서 선언한다.

> 자격증명은 `REPO_ROOT` 경로의 vault 가 아니라 Jenkins Credentials 에서 주입한다. 위 [Jenkins Credentials](#jenkins-credentials-자격증명-주입) 섹션 참고.

## 인벤토리 설정

인벤토리는 **Jenkins Agent 에 고정 배치**되어 있으며 경로는 `/etc/ansible/ansible.cfg` 에서 관리한다.
자세한 절차는 [`ansible-cfg-guide.md`](./ansible-cfg-guide.md) 참고.

```ini
# /etc/ansible/ansible.cfg (Agent 측)
[defaults]
inventory = /opt/ansible-env/inventory/my_inventory.sh
```

`ansiblePlaybook()` 호출 시 `inventory` 파라미터를 **생략**하면
Ansible 이 `/etc/ansible/ansible.cfg` 의 `inventory` 설정을 자동으로 사용한다.

> Jenkinsfile 에 `inventory` 파라미터를 적지 않는다.
> 작업 저장소 루트에 `ansible.cfg` 를 두지 않는다 (CWD 의 `ansible.cfg` 가 `/etc/ansible/ansible.cfg` 를 가리기 때문).
