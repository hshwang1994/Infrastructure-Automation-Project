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
                    string(credentialsId: 'ansible-infra-user', variable: 'ANSIBLE_REMOTE_USER'),
                    string(credentialsId: 'ansible-infra-pass', variable: 'ANSIBLE_REMOTE_PASS')
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

> 위 예시는 **linux / windows 공용 계정 (`infra` / `infra1234`)** 기준이다.
> ESXi / Redfish 는 [Jenkins Credentials](#jenkins-credentials-자격증명-주입) 섹션의 별도 ID 표 참고.

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

**linux / windows 공용 (현재 사양: `infra` / `infra1234`)**

| Credential ID | 종류 | 값 | 매핑되는 ansible 변수 |
|---|---|---|---|
| `ansible-infra-user` | Secret Text | `infra` | `ansible_user` |
| `ansible-infra-pass` | Secret Text | `infra1234` | `ansible_password`, `ansible_become_password` |

**ESXi (별도 ID 필요)**

| Credential ID | 종류 | 매핑되는 ansible 변수 |
|---|---|---|
| `ansible-esxi-user` | Secret Text | `ansible_user` |
| `ansible-esxi-pass` | Secret Text | `ansible_password` |

**Redfish (vendor 별 분리)**

| Credential ID | 종류 | 매핑되는 ansible 변수 |
|---|---|---|
| `ansible-redfish-dell-user` / `ansible-redfish-dell-pass` | Secret Text | iDRAC 계정 |
| `ansible-redfish-hpe-user` / `ansible-redfish-hpe-pass` | Secret Text | iLO 계정 |
| `ansible-redfish-lenovo-user` / `ansible-redfish-lenovo-pass` | Secret Text | XCC 계정 |
| `ansible-redfish-supermicro-user` / `ansible-redfish-supermicro-pass` | Secret Text | SMC IPMI 계정 |

### target_type 별 withCredentials 패턴

**linux** (sudo become 포함):
```groovy
withCredentials([
    string(credentialsId: 'ansible-infra-user', variable: 'U'),
    string(credentialsId: 'ansible-infra-pass', variable: 'P')
]) {
    ansiblePlaybook(
        installation: 'ansible',
        playbook    : "${WORKSPACE}/{작업경로}/site.yml",
        extraVars   : [
            ansible_user           : [value: "${U}", hidden: true],
            ansible_password       : [value: "${P}", hidden: true],
            ansible_become_password: [value: "${P}", hidden: true]
        ],
        colorized: true
    )
}
```

**windows** (WinRM, become 없음):
```groovy
withCredentials([
    string(credentialsId: 'ansible-infra-user', variable: 'U'),
    string(credentialsId: 'ansible-infra-pass', variable: 'P')
]) {
    ansiblePlaybook(
        installation: 'ansible',
        playbook    : "${WORKSPACE}/{작업경로}/site.yml",
        extraVars   : [
            ansible_user    : [value: "${U}", hidden: true],
            ansible_password: [value: "${P}", hidden: true]
        ],
        colorized: true
    )
}
```

> WinRM 연결 옵션(`ansible_connection`, `ansible_winrm_transport` 등)은 playbook 의 `vars` 블록에 넣는다 ([`playbook-guide.md`](./playbook-guide.md) 의 windows 예시 참고). 시크릿이 아니므로 코드에 두어도 무방.

**redfish** (vendor 별 credential 선택):
```groovy
script {
    def vendor = '...'   // 포털 입력 또는 inventory_json 의 vendor 필드에서 추출
    withCredentials([
        string(credentialsId: "ansible-redfish-${vendor}-user", variable: 'U'),
        string(credentialsId: "ansible-redfish-${vendor}-pass", variable: 'P')
    ]) {
        ansiblePlaybook(
            installation: 'ansible',
            playbook    : "${WORKSPACE}/{작업경로}/site.yml",
            extraVars   : [
                ansible_user    : [value: "${U}", hidden: true],
                ansible_password: [value: "${P}", hidden: true]
            ],
            colorized: true
        )
    }
}
```

> Redfish 는 한 번에 한 vendor 만 처리한다는 전제. 여러 vendor 가 섞이면 vendor 별 stage 분리 권장.

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
