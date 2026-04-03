# GUIDE FOR AI

이 파일과 기존 Jenkinsfile / Playbook 을 함께 AI 프롬프트에 넣으면,
AI 가 이 프로젝트의 컨벤션에 맞게 리팩토링해준다.

---

## 1. Repo 구조

```
Infrastructure-Automation-Project/
  inventory/
    my_inventory.sh        ← 동적 인벤토리 스크립트 (모든 작업에서 공통 사용)
  vault/
    linux.yml              ← Linux 접속 계정
    windows.yml            ← Windows 접속 계정
    esxi.yml               ← ESXi 접속 계정
    redfish/
      dell.yml             ← Dell BMC 접속 계정
      hpe.yml / lenovo.yml / supermicro.yml
  playbooks/
    day1/                  ← 서버 최초 구성 작업
    day2/                  ← 운영 작업 (점검, 패치, 펌웨어 등)
  docs/
    jenkinsfile-guide.md   ← Jenkinsfile 작성 표준 (상세)
    playbook-guide.md      ← Playbook 작성 표준 (상세)
```

---

## 2. Jenkinsfile 컨벤션

### 예약 파라미터 (3개 필수)

모든 Jenkinsfile 에는 반드시 아래 3개 파라미터가 있어야 한다.
포털이 전달하는 값이므로 `defaultValue` 는 빈 값으로 유지한다.

```groovy
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
    "vendor": ""
  }
]''',
        description : '포털에서 전달하는 타겟 호스트 JSON'
    )
}
```

### environment 블록 (3개 필수)

```groovy
environment {
    INVENTORY_JSON = "${params.inventory_json}"
    TARGET_TYPE    = "${params.target_type}"
    REPO_ROOT      = "${WORKSPACE}"
}
```

### ansiblePlaybook 호출

```groovy
ansiblePlaybook(
    installation: 'ansible',
    playbook    : "${WORKSPACE}/playbooks/작업경로/site.yml",
    colorized   : true
)
```

> `installation: 'ansible'` 은 Jenkins Global Tool Configuration 에 등록된 Ansible 이름이다.
> 경로(`/opt/ansible-env/bin`)는 Jenkins 설정에서 관리하며 Jenkinsfile 에 하드코딩하지 않는다.

> `inventory` 파라미터는 생략한다. 프로젝트 루트의 `ansible.cfg` 에서 `./inventory/my_inventory.sh` 를 기본 인벤토리로 지정하고 있다.

### inventory_json defaultValue 작성법

`defaultValue` 는 포털이 jspreadsheet 컬럼 정의로 사용한다.
**기본 4개 필드(`bmc_ip`, `service_ip`, `hostname`, `vendor`)는 항상 포함**하고,
확장 필드가 필요하면 뒤에 추가한다.

포털이 값을 안 던져주는 필드는 빈 문자열로 들어오며, 정상 동작한다.

**기본 (모든 Jenkinsfile 공통):**
```groovy
defaultValue: '''[
  { "bmc_ip": "", "service_ip": "", "hostname": "", "vendor": "" }
]'''
```

**확장 필드가 필요한 경우 (예: BMC OS 설치):**
```groovy
defaultValue: '''[
  {
    "bmc_ip": "", "service_ip": "", "hostname": "", "vendor": "",
    "mgmt_ip": "", "storage_ip": "", "gateway": "", "netmask": "",
    "dns_servers": "", "os_image": "", "boot_mode": ""
  }
]'''
```

---

## 3. Playbook 컨벤션

### 서버 타입별 기준

| target_type | connection | gather_facts | vault 파일 |
|------------|-----------|--------------|-----------|
| linux | ssh | true (운영) / false (OS 설치 전) | vault/linux.yml |
| windows | winrm | true (운영) / false (OS 설치 전) | vault/windows.yml |
| esxi | ssh | true (운영) / false (OS 설치 전) | vault/esxi.yml |
| redfish | local | false | vault/redfish/{vendor}.yml |

### vault 참조

```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
```

redfish 에서 vendor 별 vault 를 동적으로 로딩하려면:
```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/redfish/{{ hostvars[inventory_hostname]['vendor'] }}.yml"
```

### 공통 변수 패턴

모든 playbook 에서 아래 변수를 선언하면 로그 출력 시 일관성을 유지할 수 있다.

```yaml
vars:
  _host: "{{ inventory_hostname }}"
  _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] | default(inventory_hostname) }}"
```

### hosts 는 항상 all

```yaml
hosts: all
```

> my_inventory.sh 가 모든 호스트를 all 그룹으로 출력하기 때문이다.

---

## 4. 인벤토리 라우터

인벤토리 스크립트(`my_inventory.sh`)는 라우터 역할만 한다.

### inventory_hostname 결정 규칙

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | `bmc_ip` 값 | `bmc_ip` 값 |
| linux / windows / esxi | `hostname` 값 | `service_ip` 값 |

### 스크립트가 사용하는 필드 (3개만)

| 필드 | 사용 조건 | 역할 |
|------|----------|------|
| `bmc_ip` | target_type == redfish | inventory_hostname + ansible_host |
| `service_ip` | target_type != redfish | ansible_host |
| `hostname` | target_type != redfish | inventory_hostname |

### 나머지 필드 = 전부 통과

위 3개 외의 모든 필드는 이름이 뭐든 값이 뭐든 `hostvars` 에 그대로 전달된다.
포털은 작업에 따라 어떤 필드든 자유롭게 추가할 수 있으며,
playbook 에서 `hostvars[inventory_hostname]['필드명']` 으로 참조한다.

```yaml
# 포털이 보낸 확장 필드 참조
_mgmt_ip:    "{{ hostvars[inventory_hostname]['mgmt_ip'] | default('') }}"
_storage_ip: "{{ hostvars[inventory_hostname]['storage_ip'] | default('') }}"
_os_image:   "{{ hostvars[inventory_hostname]['os_image'] }}"
```

> 선택 필드는 `| default('')` 를 붙여서 누락 시에도 에러가 나지 않게 한다.

---

## 5. 리팩토링 체크리스트

AI 가 기존 Jenkinsfile / Playbook 을 리팩토링할 때 아래를 확인한다.

### Jenkinsfile

- [ ] `loc`, `target_type`, `inventory_json` 3개 파라미터가 있는가?
- [ ] `defaultValue` 가 빈 값인가? (테스트용 IP 하드코딩 금지)
- [ ] `environment` 에 `INVENTORY_JSON`, `TARGET_TYPE`, `REPO_ROOT` 가 있는가?
- [ ] `inventory` 파라미터를 생략했는가? (ansible.cfg 에서 관리)
- [ ] `playbook` 경로가 `${WORKSPACE}/playbooks/...` 로 시작하는가?
- [ ] `installation: 'ansible'` 파라미터가 포함되어 있는가?

### Playbook

- [ ] `hosts: all` 인가?
- [ ] `connection` 이 target_type 에 맞는가? (ssh / winrm / local)
- [ ] `vars_files` 로 vault 를 올바르게 참조하는가?
- [ ] `_host`, `_ip` 공통 변수를 사용하는가?
- [ ] 확장 필드 참조 시 `| default('')` 를 붙였는가?
- [ ] `changed_when: false` 로 읽기 전용 태스크를 표시했는가?
- [ ] block/rescue 로 실패 처리를 했는가? (선택)

---

## 6. AI 에게 요청하는 방법

### 기존 파일 리팩토링

```
아래 Jenkinsfile 과 Playbook 을 이 프로젝트 컨벤션에 맞게 리팩토링해줘.
GUIDE_FOR_AI.md 를 참고해서 파라미터, 환경변수, vault, inventory 를 맞춰줘.

[기존 Jenkinsfile 붙여넣기]
[기존 Playbook 붙여넣기]
```

### 새 작업 생성

```
이 프로젝트 컨벤션에 맞게
playbooks/day2/ntp-sync/linux/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
NTP 서버 동기화 작업이고 대상은 Linux 야.
```

### 확장 필드가 필요한 작업

```
이 프로젝트 컨벤션에 맞게
playbooks/day1/os-install/redfish/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
BMC 통한 OS 설치이고, 포털에서 아래 필드가 들어와:
bmc_ip, service_ip, hostname, vendor, gateway, netmask, dns_servers, os_image, boot_mode
```

---

## 7. 부하 테스트

Jenkins/Ansible 부하 테스트는 별도 레포에서 관리합니다.
이 repo 에는 부하 테스트 코드가 없습니다.

---

## 8. 상세 가이드

더 자세한 내용은 아래 문서를 참조한다.

- **Jenkinsfile 상세**: `docs/jenkinsfile-guide.md`
- **Playbook 상세**: `docs/playbook-guide.md`
