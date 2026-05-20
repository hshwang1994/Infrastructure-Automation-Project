# Playbook 가이드

실제 예시는 `playbook/` 의 각 작업 디렉토리 site.yml 참고.

## target_type 별 기본값

| target_type | connection | gather_facts | become | vault 파일 |
|------------|-----------|--------------|--------|-----------|
| linux | ssh | true | true (sudo) | `vault/linux.yml` |
| windows | winrm | true | false | `vault/windows.yml` |
| esxi | ssh | true | false | `vault/esxi.yml` |
| redfish | local | false | false | `vault/redfish.yml` |

`gather_facts` 는 OS 설치 전 단계에서는 `false`.

## 필수 구조

```yaml
- hosts: all
  connection: ssh
  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
  tasks:
    - ...
```

- `hosts: all` 고정 (인벤토리가 단일 그룹).
- `vars_files` 로 `vault/{target_type}.yml` 로딩 → `ansible_user` / `ansible_password` (linux 는 `ansible_become_password` 추가) 변수 노출.
- windows 는 WinRM 비-시크릿 옵션을 `vars` 블록에 둔다 (`ansible_winrm_transport`, `ansible_port` 등).

## 포털이 보낸 값을 playbook 에서 쓰는 법

포털은 작업마다 이런 JSON 을 보냅니다:

```json
[{"bmc_ip": "10.0.1.1", "service_ip": "10.0.2.1", "hostname": "WEB-01", "vendor": "dell"}]
```

`inventory/my_inventory.sh` 가 이걸 받아서 ansible 한테 두 가지를 정해줍니다.

### 1. 호스트의 이름과 접속 IP

- **이름** (`inventory_hostname`): 로그에 `[WEB-01]` 처럼 찍히는 식별자
- **접속 IP** (`ansible_host`): 실제로 SSH/WinRM/HTTPS 로 붙는 주소

target_type 마다 다릅니다:

| target_type | 이름 (inventory_hostname) | 접속 IP (ansible_host) | 왜 |
|---|---|---|---|
| linux / windows / esxi | `hostname` 값 (예: WEB-01) | `service_ip` 값 | OS 가 있는 서버는 hostname 으로 식별하는 게 자연스럽다 |
| redfish | `bmc_ip` 값 (예: 10.0.1.1) | `bmc_ip` 값 | BMC 에는 hostname 이 없으니 IP 가 곧 이름 |

playbook 에서:
- `{{ inventory_hostname }}` → 그 호스트의 "이름"
- `{{ hostvars[inventory_hostname]['ansible_host'] }}` → 접속 IP

### 2. 나머지 필드 (`vendor`, `mgmt_ip` 등) 꺼내기

포털이 보낸 다른 필드는 전부 `hostvars` 라는 곳에 그대로 들어갑니다. 꺼내는 법:

```yaml
- debug:
    msg: "{{ hostvars[inventory_hostname]['vendor'] }}"
```

규칙 둘:

- **이름으로 쓴 필드는 hostvars 에서 빠집니다.** 예: linux 면 `hostname` 이 `inventory_hostname` 자체로 이미 잡혀서 hostvars 에는 안 들어갑니다. 그 필드가 필요하면 `inventory_hostname` 으로 참조하세요.
- **포털이 그 필드를 항상 보낸다는 보장이 없으면** `| default('')` 를 붙여서 없을 때 빈 문자열로 대체:

  ```yaml
  "{{ hostvars[inventory_hostname]['mgmt_ip'] | default('') }}"
  ```

자세한 변환 로직은 `inventory/my_inventory.sh` 의 상단 docstring 에 입출력 예시와 함께 있습니다.

## 직접 실행

Jenkins 없이 돌릴 때:

```
ansible-playbook playbook/linux/ntp/site.yml --ask-vault-pass
```
