# GUIDE FOR AI

이 파일을 AI 프롬프트에 넣으면 AI 가 우리 환경(공통 인벤토리 + 공용 Jenkins Agent + Vault)
컨벤션에 맞게 Jenkinsfile / Playbook 을 작성하거나 리팩토링한다.

> 이 저장소는 **표준 가이드 저장소**이며 실제 작업 코드는 별도 작업 저장소에 있다.
> AI 는 이 저장소의 표준을 따르되, 산출물은 사용자가 지정하는 작업 저장소 경로에 만든다.

---

## 1. Repo 구조 (가이드 저장소)

```
automation-standards-guide/
  inventory/
    my_inventory.sh        ← 동적 인벤토리 스크립트 (모든 작업에서 공통 사용)
  vault/
    linux.yml              ← Linux 접속 계정 템플릿
    windows.yml            ← Windows 접속 계정 템플릿
    esxi.yml               ← ESXi 접속 계정 템플릿
    redfish/
      dell.yml             ← Dell BMC 접속 계정 템플릿
      hpe.yml / lenovo.yml / supermicro.yml
  docs/
    ansible-cfg-guide.md   ← ansible.cfg 표준
    jenkinsfile-guide.md   ← Jenkinsfile 작성 표준 (상세)
    playbook-guide.md      ← Playbook 작성 표준 (상세)
```

> 작업 저장소 쪽의 Playbook 디렉터리 구조는 작업 저장소 README 에서 별도 정의한다.
> 이 가이드는 **각 파일을 어떻게 작성할지**에만 책임을 진다.

---

## 2. Jenkinsfile 컨벤션

### 예약 파라미터 (3개 필수)

모든 Jenkinsfile 에는 반드시 아래 3개 파라미터가 있어야 한다.
포털이 전달하는 값이므로 `defaultValue` 는 빈 값으로 유지한다.
`inventory_json` 은 배열 형태 힌트용 `'[]'` 만 두고, 필드/값 정의는 포털이 자체 관리한다.

```groovy
parameters {
    string(name: 'loc',         defaultValue: '', description: '포털 전달: Agent 위치 (ich | chj | yi)')
    string(name: 'target_type', defaultValue: '', description: '포털 전달: 대상 종류 (linux | windows | esxi | redfish)')
    text(
        name        : 'inventory_json',
        defaultValue: '[]',
        description : '포털 전달: 타겟 호스트 JSON 배열'
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
    playbook    : "${WORKSPACE}/{작업경로}/site.yml",
    colorized   : true
)
```

> `installation: 'ansible'` 은 Jenkins Global Tool Configuration 에 등록된 Ansible 이름이다.
> 경로(`/opt/ansible-env/bin`)는 Jenkins 설정에서 관리하며 Jenkinsfile 에 하드코딩하지 않는다.

> `inventory` 파라미터는 생략한다. Agent 의 `/etc/ansible/ansible.cfg` 가 `/opt/ansible-env/inventory/my_inventory.sh` 를 기본 인벤토리로 지정하고 있다. 자세한 절차는 [`docs/ansible-cfg-guide.md`](./docs/ansible-cfg-guide.md) 참고.

### inventory_json defaultValue 작성법

`defaultValue` 는 **항상 `'[]'`** 만 둔다. 필드/값 정의는 Jenkinsfile 의 책임이 아니다.

- 포털이 작업별 필드 스키마를 자체적으로 관리하고, 실행 시 전체 JSON 을 채워서 전달한다.
- "배열이다" 와 "필수 필드가 있다" 는 검증은 `inventory/my_inventory.sh` 가 전담한다.
- 따라서 Jenkinsfile 에 필드 목록을 박지 않는다 — 작업이 추가될 때 Jenkinsfile 을 안 건드려도 된다.

```groovy
text(
    name        : 'inventory_json',
    defaultValue: '[]',
    description : '포털 전달: 타겟 호스트 JSON 배열'
)
```

> 수동 빌드(Build with Parameters) 시에는 빈 배열 `[]` 로 시작 → `my_inventory.sh` 가 즉시 "배열이 비어있다" 에러로 안전하게 막는다.

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

### 스크립트가 키로 소비하는 필드

| 필드 | 사용 조건 | 역할 |
|------|----------|------|
| `bmc_ip` | target_type == redfish | inventory_hostname + ansible_host |
| `service_ip` | target_type != redfish | ansible_host |
| `hostname` | target_type != redfish | inventory_hostname |

### hostvars 에 무엇이 남는가 (실측 기준)

규칙: **inventory_hostname 으로 쓴 필드만 hostvars 에서 제외**되고, 나머지는 전부 그대로 통과한다. 거기에 `ansible_host` 가 추가된다.

| target_type | hostvars 에서 빠지는 필드 | hostvars 에 항상 추가되는 키 |
|------------|--------------------------|----------------------------|
| redfish | `bmc_ip` | `ansible_host` (= bmc_ip) |
| linux / windows / esxi | `hostname`, `service_ip` | `ansible_host` (= service_ip) |

핵심:
- **linux 에서도 `bmc_ip` 는 hostvars 에 남는다** (입력에 포함됐다면)
- **redfish 에서도 `hostname`, `service_ip` 는 hostvars 에 남는다** (입력에 포함됐다면)
- 빈 문자열로 들어온 필드도 hostvars 에 키가 존재한다 (값만 `""`)

자세한 실측 입출력은 [`docs/playbook-guide.md`](./docs/playbook-guide.md) 의 "3. hostvars 가 실제로 어떻게 채워지는가" 섹션 참고.

```yaml
# 포털이 보낸 확장 필드 참조 — 작업에 따라 누락 가능하면 default 필수
_mgmt_ip:    "{{ hostvars[inventory_hostname]['mgmt_ip']    | default('') }}"
_storage_ip: "{{ hostvars[inventory_hostname]['storage_ip'] | default('') }}"
_os_image:   "{{ hostvars[inventory_hostname]['os_image']   | default('') }}"
```

> `inventory_hostname` 과 `ansible_host` 는 `my_inventory.sh` 가 보장하므로 default 불필요.
> 그 외 필드는 포털이 그 작업에서 보낼지 보장 안 되면 `| default('')` 권장.

---

## 5. 리팩토링 체크리스트

AI 가 기존 Jenkinsfile / Playbook 을 리팩토링할 때 아래를 확인한다.

### Jenkinsfile

- [ ] `loc`, `target_type`, `inventory_json` 3개 파라미터가 있는가?
- [ ] `loc`, `target_type` 의 `defaultValue` 가 빈 문자열인가? (테스트용 값 하드코딩 금지)
- [ ] `inventory_json` 의 `defaultValue` 가 `'[]'` 인가? (필드 스키마 박지 않기)
- [ ] `agent` 라벨이 `"${params.loc} && ${params.target_type}"` 인가?
- [ ] `environment` 에 `INVENTORY_JSON`, `TARGET_TYPE`, `REPO_ROOT` 가 있는가?
- [ ] `inventory` 파라미터를 생략했는가? (ansible.cfg 에서 관리)
- [ ] `playbook` 경로가 `${WORKSPACE}/...` 로 시작하는가? (작업 저장소 기준 절대경로)
- [ ] `installation: 'ansible'` 파라미터가 포함되어 있는가?

### Playbook

- [ ] `hosts: all` 인가?
- [ ] `connection` 이 target_type 에 맞는가? (ssh / winrm / local)
- [ ] `vars_files` 로 vault 를 올바르게 참조하는가? (redfish 는 vendor 별 분기)
- [ ] `_host`, `_ip` 공통 변수를 사용하는가?
- [ ] 포털이 보낼지 보장 안 되는 필드에 `| default('')` 를 붙였는가?
- [ ] `changed_when: false` 로 읽기 전용 태스크를 표시했는가?
- [ ] hostvars 를 소비만 하는가? (setting/mutating 금지)
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
automation-standards-guide 컨벤션에 맞게
{작업 저장소 경로}/{작업명}/{OS타입}/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
NTP 서버 동기화 작업이고 대상은 Linux 야.
```

### 확장 필드가 필요한 작업

```
automation-standards-guide 컨벤션에 맞게
{작업 저장소 경로}/{작업명}/redfish/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
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
