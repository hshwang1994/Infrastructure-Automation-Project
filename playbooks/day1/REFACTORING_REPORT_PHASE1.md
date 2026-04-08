# Phase 1 최소 수정 리팩토링 보고서

대상: `ansi-test-master_20260407.zip` (Jenkins + Ansible 기반 Dell / HP / Lenovo 의
OS install / BIOS / RAID 워크플로우)
배치 위치: `playbooks/day1/`

---

## 1. 이번 단계의 범위 (Single-Host)

이번 Phase 1 은 legacy 워크플로우를 **그대로 유지하면서** Jenkins-측에서
딱 두 가지만 표준화한다.

1. **Jenkins parameter 스키마 표준화**
   - 기존: 워크플로우마다 제각각인 string 파라미터들
   - 신규: `loc / target_type / inventory_json` (3개) — 포털 표준
2. **Ansible 실행 방식 교체**
   - 기존: `sh "ansible-playbook --vault-password-file=/dev/stdin <<< $VAULT_PASS ..."`
   - 신규: `ansiblePlaybook(...)` Ansible plugin 호출

> 멀티호스트는 **이번 단계에서 다루지 않는다.** `inventory_json` 배열에
> host 가 여러 개 들어와도 `inv[0]` 한 건만 사용한다. 멀티호스트는 향후
> phase 의 별도 작업으로 분리한다.

### 명시적 비범위 (untouched)

- 모든 legacy role / task / template 본문 — 무수정
- vendor 분리 (`bmc/lenovo|hp|dell`, `bios/...`, `raid/...`) — 그대로
- 폴더 구조, 변수명 — 그대로
- vault (`group_vars/all.yml` AES256) — byte-identical
- legacy `ansible.cfg`, `roles_path`, vault config — 그대로
- 새 bridge playbook (`_entry.yml` 같은 것) **만들지 않는다**
- `INSTALL_JSON` 재조립 / `-e` 로 host 데이터 전달 — 안 함

---

## 2. 산출물 트리

```
playbooks/day1/
├── REFACTORING_REPORT_PHASE1.md          ← 본 문서
├── ansible/                              ← legacy ansi-test-master 트리 (수정점만)
│   ├── ansible.cfg
│   ├── group_vars/all.yml                ← vault, byte-identical
│   ├── group_vars/ESXi/var.yml
│   ├── playbooks/                        ← 63 stage YAML, 각 play-level vars: 블록만 추가
│   │   ├── installRhel/      stage01..stage17 (17)
│   │   ├── installWindows/   stage01..stage17 (17)
│   │   ├── installESXi/      stage01..stage18 (18)
│   │   ├── dellBios/         stage01..stage02 (2)
│   │   ├── hpBios/           stage01..stage02 (2)
│   │   ├── lenovoBios/       stage01..stage03 (3)
│   │   ├── hpRaid/           stage01..stage02 (2)
│   │   └── lenovoRaid/       stage01..stage02 (2)
│   └── roles/                            ← 무수정
└── pipelines/                            ← 8 Jenkinsfile, 모두 신규 패턴
    ├── jenkins_groovy_rhel
    ├── jenkins_groovy_win
    ├── jenkins_groovy_esxi
    ├── jenkins_groovy_bios_DellR740
    ├── jenkins_groovy_bios_HpDL380Gen11
    ├── jenkins_groovy_bios_LenovoSR650_V2
    ├── jenkins_groovy_raid_HpDL380Gen11
    └── jenkins_groovy_raid_LenovoSR650_V2
```

`_entry.yml` (이전 iteration 의 bridge playbook) 은 **제거되었다.** 새 파일을
만들지 않고 기존 stage YAML 만 최소 수정한다.

---

## 3. inventory_json 데이터 흐름

```
포털 / 호출자
   │
   │  POST  loc, target_type, inventory_json (JSON 배열)
   ▼
Jenkins job
   │  parameters: loc / target_type / inventory_json
   │  environment.INVENTORY_JSON = params.inventory_json
   │  environment.TARGET_TYPE    = params.target_type
   │
   │  parse_inventory_json stage:
   │    - target_type == 'redfish' 검증
   │    - inventory_json 배열 비어있지 않은지 검증
   │    - host 가 1개 이상이면 [0] 만 쓴다는 WARN echo
   │
   │  각 stage 마다 runStage(stageFile) 헬퍼 호출
   │    └─ dir('playbooks/day1/ansible') { ansiblePlaybook(...) }
   ▼
Ansible (legacy stage YAML, 수정 1군데 — play-level vars: 블록)
   │
   │  vars:
   │    _inv: "{{ lookup('env','INVENTORY_JSON') | from_json }}"
   │    _h:   "{{ _inv[0] }}"
   │    rhel_hostname: "{{ _h.rhel_hostname | default('') }}"
   │    physical_ip:   "{{ _h.physical_ip   | default('') }}"
   │    ip:            "{{ _h.ip            | default('') }}"
   │    vendor:        "{{ _h.vendor        | default('') }}"
   │    ...
   │
   │  tasks: (legacy 본문, 무수정)
   │    - include_role: name: ... tasks_from: ...
   ▼
legacy roles (무수정) — vendor / physical_ip / ip / hostname / ...
                       이미 자기 자리에 들어와 있다
```

핵심 포인트:

- legacy stage 가 **자기 자신의 play-level vars: 에서** `INVENTORY_JSON` 을
  직접 읽는다. Jinja 의 lazy evaluation 덕분에 `vars:` 블록은 환경변수가
  주어진 시점에만 평가된다.
- `inventory_json` 의 **키 이름은 legacy 변수명을 그대로 사용한다**
  (`physical_ip`, `ip`, `rhel_hostname`, `dns_name`, `dns_server`, `gateway`,
  `ntp_server`, `vlan_id`, `rhel_version` / `win_version` / `esxi_version`,
  `username`, `vendor`, `system_profile`, `workload_profile`, ...).
  포털 표준 키 (`bmc_ip` / `service_ip` / `hostname`) 로 정규화하는 일은
  이번 단계에서 하지 않는다.
- 여러 host 가 들어와도 `_h = _inv[0]`. day1 워크플로우는 단일 호스트
  모델이다.

---

## 4. 워크플로우별 legacy 변수 매핑표

`inventory_json[0]` 에 들어가야 하는 키 목록 (legacy 변수명).

| 워크플로우       | 키                                                                                                                                          |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `installRhel`    | `rhel_hostname`, `dns_name`, `ip`, `physical_ip`, `gateway`, `dns_server`, `ntp_server`, `vlan_id`, `rhel_version`, `username`, `vendor`     |
| `installWindows` | `win_hostname`,  `dns_name`, `ip`, `physical_ip`, `gateway`, `dns_server`, `ntp_server`, `vlan_id`, `win_version`,  `username`, `vendor`     |
| `installESXi`    | `esxi_hostname`, `dns_name`, `ip`, `physical_ip`, `gateway`, `dns_server`, `ntp_server`, `vlan_id`, `esxi_version`, `username`, `vendor`     |
| `dellBios`       | `physical_ip`, `username`, `vendor`, `system_profile`                                                                                       |
| `hpBios`         | `physical_ip`, `username`, `vendor`, `workload_profile`, `acpi_slit`, `thermal_shutdown`, `fan_fail_policy`, `daylight_saving_time`         |
| `lenovoBios`     | `physical_ip`, `username`, `vendor`, `OperatingMode_STP1`, `OperatingMode_STP2`, `MONITORMWAIT`, `CStates`, `Intel_VT`                      |
| `hpRaid`         | `physical_ip`, `username`, `vendor`                                                                                                         |
| `lenovoRaid`     | `physical_ip`, `username`, `vendor`                                                                                                         |

각 Jenkinsfile 의 `inventory_json` 파라미터 `defaultValue` 에 위 키를 채운
샘플 JSON 이 들어 있다.

---

## 5. legacy stage 파일 수정 패턴 (63 파일 공통)

수정은 한 가지 패턴뿐이다 — **play-level `vars:` 블록에 inventory_json
주입 라인 추가**. role / task / template 본문에는 손대지 않았다.

### 5.1 기존에 `vars:` 블록이 없던 stage (예: `installRhel/stage01_checkParameters.yml`)

```yaml
---
- hosts: localhost
  gather_facts: true
  connection: local

  vars:
    # >>> phase1 inventory_json injection >>>
    _inv: "{{ lookup('env', 'INVENTORY_JSON') | from_json }}"
    _h:   "{{ _inv[0] }}"
    rhel_hostname: "{{ _h.rhel_hostname | default('') }}"
    dns_name:      "{{ _h.dns_name      | default('') }}"
    ip:            "{{ _h.ip            | default('') }}"
    physical_ip:   "{{ _h.physical_ip   | default('') }}"
    gateway:       "{{ _h.gateway       | default('') }}"
    dns_server:    "{{ _h.dns_server    | default('') }}"
    ntp_server:    "{{ _h.ntp_server    | default('') }}"
    vlan_id:       "{{ _h.vlan_id       | default('') }}"
    rhel_version:  "{{ _h.rhel_version  | default('') }}"
    username:      "{{ _h.username      | default('') }}"
    vendor:        "{{ _h.vendor        | default('') }}"
    # <<< phase1 inventory_json injection <<<

  tasks:
    - name: Validate vendor variable
      ansible.builtin.assert:
        ...
    - name: "Check parameters variable"
      include_role:
        name: installRhel
        tasks_from: check_parameters.yml
```

### 5.2 기존에 `vars:` 블록이 있던 stage (예: `installRhel/stage14_serverReboot.yml`)

```yaml
  vars:
    # >>> phase1 inventory_json injection >>>
    _inv: "{{ lookup('env', 'INVENTORY_JSON') | from_json }}"
    _h:   "{{ _inv[0] }}"
    rhel_hostname: "{{ _h.rhel_hostname | default('') }}"
    ...
    vendor:        "{{ _h.vendor        | default('') }}"
    # <<< phase1 inventory_json injection <<<
    vendor_name:               # ← legacy block, 손대지 않음
      lenovo:
        role: bmc
        task: lenovo/server_reboot.yml
      hp:
        role: bmc
        task: hp/server_reboot.yml
```

### 5.3 패치 통계

```
installRhel       17 파일  (new-vars 13, extend-vars 4)
installWindows    17 파일  (new-vars 13, extend-vars 4)
installESXi       18 파일  (new-vars 18, extend-vars 0)
dellBios           2 파일  (new-vars 0,  extend-vars 2)
hpBios             2 파일  (new-vars 0,  extend-vars 2)
lenovoBios         3 파일  (new-vars 0,  extend-vars 3)
hpRaid             2 파일  (new-vars 0,  extend-vars 2)
lenovoRaid         2 파일  (new-vars 0,  extend-vars 2)
─────────────────────────────────────────────────────
total             63 파일
```

마커 (`# >>> phase1 inventory_json injection >>>` … `# <<< … <<<`) 가 모든
주입부를 감싸고 있어 향후 phase 에서 일괄 제거 / 교체가 쉽다. 패치 스크립트는
이 마커를 보고 idempotent 하게 동작한다.

---

## 6. Jenkinsfile (8개) 신규 패턴

8개 Jenkinsfile 모두 같은 골격으로 재생성됐다.

### 6.1 parameters / environment

```groovy
parameters {
    string(name: 'loc',         defaultValue: 'ansible', trim: true, ...)
    choice(name: 'target_type', choices: ['redfish'], ...)
    text  (name: 'inventory_json', defaultValue: """[{"physical_ip":"10.50.11.232",...}]""", ...)
}

environment {
    INVENTORY_JSON = "${params.inventory_json}"
    TARGET_TYPE    = "${params.target_type}"
}
```

`-e INSTALL_JSON=...` / `-e physical_ip=...` 같은 host 데이터 extra-var 는
**없다.** Ansible 측이 `INVENTORY_JSON` 환경변수를 직접 읽기 때문이다.

### 6.2 parse_inventory_json stage

```groovy
stage('parse_inventory_json') {
    steps {
        script {
            if (params.target_type != 'redfish') {
                error("target_type must be 'redfish' (Phase 1 day1 BMC workflow)")
            }
            def inv = readJSON text: params.inventory_json
            if (!(inv instanceof List) || inv.isEmpty()) {
                error("inventory_json must be a non-empty JSON array")
            }
            if (inv.size() > 1) {
                echo "WARN: inventory_json has ${inv.size()} hosts; day1 single-host model — only inv[0] is used"
            }
            echo "inventory_json OK — first physical_ip: ${inv[0].physical_ip}"
        }
    }
}
```

### 6.3 stage 호출 — runStage 헬퍼

```groovy
def runStage(String stageFile) {
    dir('playbooks/day1/ansible') {
        ansiblePlaybook(
            installation: 'ansible',
            playbook: "playbooks/<subdir>/${stageFile}",
            vaultCredentialsId: 'ansible-vault-pass',
            colorized: true,
            extras: '-vvv'   // workflow 별 -v / -vv / -vvv
        )
    }
}
```

`<subdir>` 은 워크플로우별로 (`installRhel`, `installWindows`, `installESXi`,
`dellBios`, `hpBios`, `lenovoBios`, `hpRaid`, `lenovoRaid`) 채워진다.

verbosity 레벨:

| Workflow                              | verbosity |
|---------------------------------------|-----------|
| `installRhel` / `installWindows` / `installESXi` | `-vvv`    |
| `dellBios` / `hpBios` / `lenovoBios`             | `-v`      |
| `hpRaid` / `lenovoRaid`                          | `-vv`     |

### 6.4 dir() wrapper 가 필요한 이유

`ansiblePlaybook` 호출을 `dir('playbooks/day1/ansible')` 로 감싼 이유는 두
가지다.

1. **legacy `./ansible.cfg` 가 로드되어야 한다.** legacy `ansible.cfg` 는
   `roles_path = ./roles` 등 legacy 트리에 의존하는 설정을 포함한다. workspace
   루트에서 호출하면 agent 의 `/etc/ansible/ansible.cfg` 가 우선 적용되어
   legacy 의 `roles/` 가 발견되지 않을 수 있다.

2. **agent 의 `my_inventory.sh` 를 우회한다.** Agent 의
   `/etc/ansible/ansible.cfg` 에는 `inventory =
   /opt/ansible-env/inventory/my_inventory.sh` 가 박혀 있다. 그런데
   `my_inventory.sh` 는 portal 표준 키 (`bmc_ip` for redfish, `hostname` /
   `service_ip` for OS) 를 기대한다. 이번 iteration 의 `inventory_json` 은
   **legacy 키** (`physical_ip` / `ip` / `rhel_hostname` / ...) 를 사용하므로
   `my_inventory.sh` 가 호출되면 `bmc_ip` 누락으로 즉시 fail 한다.
   `dir()` 로 legacy 디렉터리에 들어가면 legacy `ansible.cfg` 에는 `inventory`
   설정이 없으므로 `my_inventory.sh` 가 호출되지 않는다. legacy stage 는 모두
   `hosts: localhost` / `connection: local` 이라 inventory 자체가 필요 없다.

> Phase 2 (또는 그 이후) 에서 `inventory_json` 키를 portal 표준 키로
> 정규화하면 `my_inventory.sh` 와 통합할 수 있다. 그것은 이번 단계의 범위가
> **아니다.**

---

## 7. credential / vault 처리

- 기존: `withCredentials([string(credentialsId: 'ansible-vault-pass', variable:
  'VAULT_PASS')]) { sh "ansible-playbook --vault-password-file=/dev/stdin
  <<< $VAULT_PASS ..." }`
- 신규: `ansiblePlaybook(vaultCredentialsId: 'ansible-vault-pass', ...)`

credential id 는 그대로 `'ansible-vault-pass'` 를 사용한다. plugin 이 동일
credential 을 vault password 로 주입한다. `group_vars/all.yml` (AES256
encrypted) 은 byte-identical 로 보존된다.

---

## 8. 검증 체크리스트

수동 검증 시 다음을 확인한다.

- [ ] `playbooks/day1/ansible/_entry.yml` 이 **존재하지 않음**
- [ ] `playbooks/day1/ansible/playbooks/<workflow>/stage*.yml` 63 개 모두에
      `# >>> phase1 inventory_json injection >>>` 마커 존재
- [ ] 마커 사이의 `vars:` 블록이 워크플로우별 변수 목록과 일치
- [ ] 8 개 Jenkinsfile 의 `runStage` 가 `_entry.yml` 을 참조하지 **않음**
- [ ] 8 개 Jenkinsfile 의 `runStage` 가 `dir('playbooks/day1/ansible')` 로
      감싸져 있음
- [ ] 모든 Jenkinsfile 이 `vaultCredentialsId: 'ansible-vault-pass'` 사용
- [ ] `legacy roles/` / `legacy templates/` / `group_vars/all.yml` 무수정
- [ ] `parse_inventory_json` stage 가 `target_type == 'redfish'` 검증
- [ ] inventory_json 배열에 호스트가 2개 이상이면 WARN 출력 후 [0] 만 사용

다음과 같은 단일 호스트 호출로 smoke test 한다 (실장비 없이도 parse 단계와
ansible 호출 단계까지는 검증 가능).

```
loc            = ansible
target_type    = redfish
inventory_json = [{"physical_ip":"10.50.11.232","username":"root",
                  "vendor":"dell","system_profile":"PerfOptimized"}]
```

---

## 9. Phase 2 이후로 미룬 항목

이번 단계에서 의도적으로 손대지 않은 것들 — 향후 phase 에서 다룬다.

1. **inventory_json 키 정규화**: 현재 `physical_ip` / `ip` / `rhel_hostname`
   같은 legacy 키를 그대로 쓴다. portal 표준 키 (`bmc_ip` / `service_ip` /
   `hostname`) 로의 매핑은 별도 phase.
2. **`my_inventory.sh` 통합**: 1번이 끝나면 `dir()` wrapper 를 제거하고 agent
   의 `my_inventory.sh` 가 inventory_json 을 처리하도록 전환할 수 있다.
3. **멀티호스트 모델**: 이번 단계는 `inv[0]` single-host 만 처리한다. 멀티
   host loop / 분기 / per-host vault 는 별도 phase.
4. **roles 본문 정리**: 무수정 보존이 원칙이었으므로 role 내부 hard-coded
   변수명 / vendor 분리는 그대로다. 필요 시 별도 phase.
5. **`_entry.yml` 같은 bridge playbook 도입 여부**: 향후 멀티호스트 단계에서
   다시 검토 가능. 이번 단계에서는 만들지 않는다.

---

## 10. 변경 요약 (한 줄)

> 63 개 legacy stage YAML 의 play-level `vars:` 블록에 `INVENTORY_JSON` 환경
> 변수를 읽어 legacy 변수명으로 노출하는 12~15 줄을 추가하고, 8 개 Jenkinsfile
> 을 `loc / target_type / inventory_json` 파라미터 + `ansiblePlaybook(...)`
> plugin + `dir('playbooks/day1/ansible')` wrapper 로 재생성했다. role / task /
> template / vault 본문은 무수정. 새 bridge playbook 은 만들지 않았다. 멀티
> 호스트 / `my_inventory.sh` 통합 / 키 정규화는 향후 phase.
