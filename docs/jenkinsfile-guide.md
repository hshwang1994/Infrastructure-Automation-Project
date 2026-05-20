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
                ansiblePlaybook(
                    installation      : 'ansible',
                    playbook          : "${WORKSPACE}/{작업경로}/site.yml",
                    vaultCredentialsId: 'ansible-vault-password',
                    colorized         : true
                )
            }
        }
    }
}
```

> `vaultCredentialsId` 가 Jenkins Credential `ansible-vault-password` (Secret Text) 의 값을 ansible-playbook 의 vault 비밀번호로 전달한다.
> playbook 이 `vars_files` 로 `vault/{target_type}.yml` 을 로딩하면 ansible 이 런타임에 자동 복호화한다.
> 자세한 설정·credentials 디렉토리 워크플로우는 아래 [Jenkins Credentials](#jenkins-credentials-자격증명-주입) 섹션 참고.

## 예약 파라미터 (3개 필수)

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `loc` | string | 포털이 전달하는 Agent 위치 (ich \| chj \| yi) |
| `target_type` | string | 포털이 전달하는 대상 종류 (linux \| windows \| esxi \| redfish) |
| `inventory_json` | text | 포털이 전달하는 타겟 호스트 JSON 배열 |

## Jenkins Credentials (자격증명 주입)

서버 접속 계정은 **ansible-vault 로 암호화된 파일** 로 repo 에 commit 하고, **vault 복호화 비밀번호만 Jenkins Credentials** 에 보관한다. ansible-playbook 이 런타임에 자동 복호화한다.

### 데이터 흐름

```
credentials/{type}.yml     (평문 원본 — 사람이 편집)
        ↓ scripts/encrypt-vault.sh
vault/{type}.yml           (ansible-vault 암호화 — repo 에 commit)
        ↓ Jenkins 빌드 시
Jenkins Credential
  - id: ansible-vault-password   (Secret Text)
  - value: vault 비밀번호
        ↓ ansiblePlaybook(vaultCredentialsId: 'ansible-vault-password')
ansible-playbook 실행
        ↓ playbook 의 vars_files 가 vault/{type}.yml 로딩 시 자동 복호화
ansible_user / ansible_password 가 변수로 사용됨
```

### Jenkins 측 등록 (1회)

Manage Jenkins → Credentials → System → Global credentials → Add Credentials

| 항목 | 값 |
|------|-----|
| Kind | **Secret text** |
| Secret | vault 비밀번호 (encrypt 시 입력했던 그 값) |
| ID | **`ansible-vault-password`** |

> 이 ID 가 Jenkinsfile 의 `vaultCredentialsId` 와 정확히 일치해야 한다.
> 모든 target_type 이 동일한 vault 비밀번호를 공유한다 (현재 단순화 정책).

### Jenkinsfile 표준 패턴 (모든 target_type 공통)

```groovy
stage('Run Ansible') {
    steps {
        ansiblePlaybook(
            installation      : 'ansible',
            playbook          : "${WORKSPACE}/{작업경로}/site.yml",
            vaultCredentialsId: 'ansible-vault-password',
            colorized         : true
        )
    }
}
```

- 따로 `withCredentials` 블록 / `extraVars` 가공이 필요 없다.
- `credentialsId` 와 달리 `vaultCredentialsId` 는 Secret Text 를 받아 vault 비밀번호로 사용한다.
- target_type 별 분기 불필요 — playbook 이 `vars_files` 로 자기에게 맞는 vault 파일을 로딩하면 됨.

### Playbook 측 vault 로딩

```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"     # linux 작업
  # 또는
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/windows.yml"   # windows 작업
  # 등등
```

복호화된 vault 내용이 즉시 `ansible_user`, `ansible_password` 변수로 노출. WinRM 의 `ansible_winrm_transport` 같은 비-시크릿 옵션은 vault 가 아니라 playbook `vars` 블록에 둔다.

### credentials/ 디렉토리 운영

- 평문 자격증명 편집 → `./scripts/encrypt-vault.sh` 실행 → `vault/*.yml` 갱신 → 둘 다 commit
- 자세한 워크플로우는 [`../credentials/README.md`](../credentials/README.md) 참고
- 운영 이행 시에는 `credentials/` 를 `.gitignore` 처리해 vault 만 공유하는 것도 가능

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
