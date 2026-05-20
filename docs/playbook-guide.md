# Playbook 작성 가이드

## 0. 역할 분리 (먼저 읽기)

이 프로젝트의 Ansible 호출은 다섯 계층으로 책임이 나뉜다.

| 계층 | 책임 | 산출물 |
|------|------|--------|
| `credentials/{type}.yml` | 사람이 편집하는 평문 자격증명 | ansible_user / ansible_password / (linux) ansible_become_password |
| `vault/{type}.yml` | 위를 ansible-vault 로 암호화한 결과 (repo 에 commit) | 암호화 YAML |
| Jenkins Credentials | vault 복호화 비밀번호 보관 | Secret Text `ansible-vault-password` 단 1개 |
| Jenkinsfile | `vaultCredentialsId` 로 vault 비밀번호 전달 | `ansiblePlaybook` 호출 |
| `inventory/my_inventory.sh` | 환경변수 → Ansible 인벤토리 JSON 변환 (라우터) | `inventory_hostname`, `ansible_host`, `hostvars` |
| **Playbook** | **위에서 만들어진 hostvars + vault 에서 복호화된 자격증명을 읽기만 함** | 실제 작업 수행 |

> Playbook 은 hostvars 와 `ansible_user` / `ansible_password` 를 **소비만 한다.**
> hostvars 의 구조는 `my_inventory.sh` 가, 자격증명은 vault 가 결정한다.
> Playbook 안에 시크릿을 평문으로 두지 않는다.

---

## 1. 기본 구조

```yaml
- name: 작업명
  hosts: all
  gather_facts: true   # linux/windows/esxi 운영 작업: true / OS 설치 전: false / redfish: false
  connection: ssh      # ssh / winrm / local

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/{타입}.yml"     # 시크릿 (ansible-vault 로 자동 복호화)

  vars:
    _host: "{{ inventory_hostname }}"
    _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] | default(inventory_hostname) }}"

  tasks:
    - name: ...
```

- `hosts: all` 고정. `my_inventory.sh` 가 모든 호스트를 `all` 그룹으로만 출력한다.
- `vars_files` 는 **시크릿 (vault) 로딩 용도**. ansible-playbook 이 `vaultCredentialsId` 로 받은 비밀번호로 자동 복호화한다.
- `vars` 블록의 `_host` / `_ip` 는 로그 일관성용 권장 패턴 (선택).

---

## 2. target_type 별 설정 기준

| target_type | connection | gather_facts | become | vault 파일 |
|------------|-----------|--------------|--------|-----------|
| linux | ssh | true (운영) / false (OS 설치 전) | yes (sudo) | `vault/linux.yml` |
| windows | winrm | true (운영) / false (OS 설치 전) | no | `vault/windows.yml` |
| esxi | ssh | true (운영) / false (OS 설치 전) | no | `vault/esxi.yml` |
| redfish | local | false (BMC 접속, OS Fact 수집 불가) | no | `vault/redfish.yml` |

vault 파일은 `ansible-vault encrypt` 로 생성된 암호화 YAML. 평문 원본은 `credentials/{type}.yml`. 자세한 흐름은 [`jenkinsfile-guide.md`](./jenkinsfile-guide.md) 의 "Jenkins Credentials" 섹션 참고.

---

## 3. hostvars 가 실제로 어떻게 채워지는가 (실측)

`my_inventory.sh` 의 동작을 직접 호출해서 검증한 결과다.

### 3-1. 라우팅 규칙

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | `bmc_ip` 값 | `bmc_ip` 값 |
| linux / windows / esxi | `hostname` 값 | `service_ip` 값 |

### 3-2. hostvars 안에 무엇이 들어 있는가

규칙: **inventory_hostname 으로 쓴 필드만 hostvars 에서 제외**되고, 나머지 필드는 전부 그대로 통과한다. 거기에 `ansible_host` 가 추가된다.

| target_type | hostvars 에서 빠지는 필드 | hostvars 에 항상 추가되는 키 |
|------------|--------------------------|-----------------------------|
| redfish | `bmc_ip` | `ansible_host` (= bmc_ip) |
| linux / windows / esxi | `hostname`, `service_ip` | `ansible_host` (= service_ip) |

핵심 — 자주 오해하는 부분:

- **linux/windows/esxi 에서 `bmc_ip` 는 hostvars 에 그대로 남아 있다.** (입력에 포함됐다면)
- **redfish 에서 `hostname`, `service_ip` 도 hostvars 에 그대로 남아 있다.** (입력에 포함됐다면)
- 포털이 빈 문자열로 보낸 필드도 hostvars 에 **키가 존재하며 값이 `""`** 다. 키 자체가 없는 게 아니다.

### 3-3. 실측 입출력

**입력 (포털 → 환경변수 `INVENTORY_JSON`):**
```json
[
  {
    "bmc_ip": "10.0.1.1",
    "service_ip": "10.0.2.1",
    "hostname": "WEB-01",
    "vendor": "dell",
    "mgmt_ip": "10.0.3.1",
    "os_image": "rhel-9.2"
  }
]
```

**`TARGET_TYPE=redfish` 실행 결과:**
```json
{
  "all": { "hosts": ["10.0.1.1"] },
  "_meta": {
    "hostvars": {
      "10.0.1.1": {
        "ansible_host": "10.0.1.1",
        "service_ip": "10.0.2.1",
        "hostname": "WEB-01",
        "vendor": "dell",
        "mgmt_ip": "10.0.3.1",
        "os_image": "rhel-9.2"
      }
    }
  }
}
```

**`TARGET_TYPE=linux` 실행 결과:**
```json
{
  "all": { "hosts": ["WEB-01"] },
  "_meta": {
    "hostvars": {
      "WEB-01": {
        "ansible_host": "10.0.2.1",
        "bmc_ip": "10.0.1.1",
        "vendor": "dell",
        "mgmt_ip": "10.0.3.1",
        "os_image": "rhel-9.2"
      }
    }
  }
}
```

### 3-4. 새 작업 만들기 전 hostvars 확인 (디버그 플레이북)

```yaml
- name: hostvars 덤프
  hosts: all
  gather_facts: false
  connection: local
  tasks:
    - ansible.builtin.debug:
        var: hostvars[inventory_hostname]
```

이 디버그 출력이 위 "3-3" 과 같은 모양이어야 한다. 다르면 인벤토리 단계에서 입력이 잘못된 것.

---

## 4. hostvars 참조 패턴

```yaml
# inventory_hostname 자체로 얻을 수 있는 것
"{{ inventory_hostname }}"
# → redfish: bmc_ip   / linux·windows·esxi: hostname

# my_inventory.sh 가 항상 채워 주는 것 (default 불필요)
"{{ hostvars[inventory_hostname]['ansible_host'] }}"
# → redfish: bmc_ip   / linux·windows·esxi: service_ip

# 포털이 보낸 필드 (작업에 따라 누락 가능 → default 권장)
"{{ hostvars[inventory_hostname]['vendor']      | default('') }}"
"{{ hostvars[inventory_hostname]['mgmt_ip']     | default('') }}"
"{{ hostvars[inventory_hostname]['os_image']    | default('') }}"

# linux 모드에서 BMC IP 가 필요할 때 (입력에 들어왔다면 사용 가능)
"{{ hostvars[inventory_hostname]['bmc_ip']      | default('') }}"

# redfish 모드에서 OS IP / hostname 이 필요할 때
"{{ hostvars[inventory_hostname]['service_ip']  | default('') }}"
"{{ hostvars[inventory_hostname]['hostname']    | default('') }}"
```

`| default('')` 기준: **포털이 그 작업에서 그 필드를 보낼지 보장 안 되는 경우.**
`inventory_hostname` 과 `ansible_host` 는 `my_inventory.sh` 가 보장하므로 default 불필요.

---

## 5. 자격증명 참조 패턴

playbook 이 `vars_files` 로 `vault/{target_type}.yml` 을 로딩하면 ansible 이 vault 비밀번호로 자동 복호화하고, 그 안의 `ansible_user` / `ansible_password` / (linux 면) `ansible_become_password` 가 변수로 노출된다.

```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"

# linux/windows/esxi — connection 이 ssh/winrm 이면 ansible 이 ansible_user/ansible_password 를 자동 사용
become: true   # linux 만, sudo 필요한 task

# redfish — uri 모듈 등에서 명시적으로 참조
- ansible.builtin.uri:
    url: "https://{{ inventory_hostname }}/redfish/v1/Systems"
    user: "{{ ansible_user }}"
    password: "{{ ansible_password }}"
```

> vault 비밀번호는 Jenkinsfile 의 `vaultCredentialsId: 'ansible-vault-password'` 가 자동 전달한다.
> 플레이북을 직접 (Jenkins 없이) 돌릴 때는 `ansible-playbook --ask-vault-pass` 또는 `--vault-password-file <file>` 로 비밀번호를 넘긴다.

---

## 6. 공통 변수 패턴 (로그 일관성)

```yaml
vars:
  _host: "{{ inventory_hostname }}"
  _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] | default(inventory_hostname) }}"
```

- `_host` 는 redfish 면 bmc_ip, linux 면 hostname → 작업 식별자
- `_ip` 는 실제 접속 IP → debug/log 출력에 사용

---

## 7. 예시 — linux 운영 작업 (NTP 동기화)

```yaml
---
- name: NTP 동기화 점검
  hosts: all
  gather_facts: true
  connection: ssh
  become: true

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"

  vars:
    _host: "{{ inventory_hostname }}"
    _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] }}"

  tasks:
    - name: chronyd 활성 상태 보장
      ansible.builtin.systemd:
        name: chronyd
        state: started
        enabled: true

    - name: 동기화 상태 조회
      ansible.builtin.command: chronyc tracking
      register: _tracking
      changed_when: false

    - name: 결과 출력
      ansible.builtin.debug:
        msg: "[{{ _host }} / {{ _ip }}] {{ _tracking.stdout_lines }}"
```

> `vault/linux.yml` 안에 `ansible_user`, `ansible_password`, `ansible_become_password` 가 들어 있고 ansible 이 자동 복호화 후 사용. Playbook 안에 다시 선언하지 않는다.

---

## 8. 예시 — windows 운영 작업 (서비스 상태 점검)

WinRM 연결 옵션(non-secret)은 playbook `vars` 에 두고, 자격증명은 vault 에서 로딩.

```yaml
---
- name: Windows 서비스 상태 점검
  hosts: all
  gather_facts: true
  connection: winrm

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/windows.yml"

  vars:
    # WinRM 비-시크릿 설정 — 그대로 노출 가능
    ansible_winrm_transport:              "ntlm"
    ansible_winrm_server_cert_validation: "ignore"
    ansible_port:                         5985
    # ansible_user / ansible_password 는 vault/windows.yml 에서 자동 로딩됨

    _host: "{{ inventory_hostname }}"
    _ip:   "{{ hostvars[inventory_hostname]['ansible_host'] }}"

  tasks:
    - name: Spooler 서비스 상태 조회
      ansible.windows.win_service:
        name: Spooler
      register: _svc

    - name: 결과 출력
      ansible.builtin.debug:
        msg: "[{{ _host }} / {{ _ip }}] Spooler={{ _svc.state }}"
```

---

## 9. 예시 — redfish (BMC 통한 OS 설치)

Jenkinsfile 은 [`jenkinsfile-guide.md`](./jenkinsfile-guide.md) 의 redfish 패턴 참고. 여기서는 `site.yml` 만 다룬다.

포털이 보내는 입력 (예):
```json
[{
  "bmc_ip": "10.0.1.1", "service_ip": "10.0.2.1", "hostname": "WEB-01",
  "vendor": "dell", "gateway": "10.0.2.254", "netmask": "255.255.255.0",
  "dns_servers": "8.8.8.8,8.8.4.4", "os_image": "rhel-9.2", "boot_mode": "uefi"
}]
```

`site.yml`:
```yaml
---
- name: BMC 통한 OS 설치
  hosts: all
  gather_facts: false
  connection: local

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/redfish.yml"

  vars:
    _bmc_ip:     "{{ inventory_hostname }}"
    _service_ip: "{{ hostvars[inventory_hostname]['service_ip'] | default('') }}"
    _hostname:   "{{ hostvars[inventory_hostname]['hostname']   | default('') }}"
    _vendor:     "{{ hostvars[inventory_hostname]['vendor'] }}"
    _gateway:    "{{ hostvars[inventory_hostname]['gateway']    | default('') }}"
    _netmask:    "{{ hostvars[inventory_hostname]['netmask']    | default('') }}"
    _dns:        "{{ hostvars[inventory_hostname]['dns_servers']| default('') }}"
    _os_image:   "{{ hostvars[inventory_hostname]['os_image']   | default('') }}"
    _boot_mode:  "{{ hostvars[inventory_hostname]['boot_mode']  | default('uefi') }}"

  tasks:
    - name: BMC Redfish 응답 확인
      ansible.builtin.uri:
        url: "https://{{ _bmc_ip }}/redfish/v1/"
        method: GET
        user: "{{ ansible_user }}"
        password: "{{ ansible_password }}"
        validate_certs: false
      register: _bmc_check
      changed_when: false

    - name: OS 설치 파라미터 요약
      ansible.builtin.debug:
        msg: >-
          [{{ _bmc_ip }}] OS={{ _os_image }} Boot={{ _boot_mode }}
          | Service IP={{ _service_ip }} GW={{ _gateway }} DNS={{ _dns }}

    # ... 이후 vendor 별 실제 OS 설치 태스크 (dell / hpe / lenovo / supermicro)
```

> Redfish 자격증명은 현재 모든 vendor 가 `vault/redfish.yml` 단일 파일을 공유. 운영에서 vendor 별 계정 분리가 필요해지면 `vault/redfish-{vendor}.yml` 로 분기 후 vendor 기준으로 `vars_files` 동적 선택.

---

## 10. 작성 체크리스트

- [ ] `hosts: all` 인가?
- [ ] `connection` 이 target_type 에 맞는가? (ssh / winrm / local)
- [ ] linux 면 `become: true` 가 필요한 task 에 설정됐는가?
- [ ] windows 면 WinRM 옵션(`ansible_winrm_transport` 등)이 `vars` 에 들어 있는가?
- [ ] `vars_files` 로 `vault/{target_type}.yml` 을 로딩하는가?
- [ ] `_host`, `_ip` 공통 변수를 선언하는가? (생략 가능, 권장)
- [ ] 포털이 보낼지 보장 안 되는 hostvars 필드에 `| default('')` 를 붙였는가?
- [ ] 읽기 전용 태스크에 `changed_when: false` 를 붙였는가?
- [ ] hostvars 를 **소비만** 하는가? (setting/mutating 하지 않는가)
- [ ] **자격증명을 playbook 안에 평문으로 두지 않았는가?** (vault 만 사용)
