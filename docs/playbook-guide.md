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

## hostvars

인벤토리 스크립트(`inventory/my_inventory.sh`)가 만든다. 라우팅 규칙:

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | bmc_ip | bmc_ip |
| linux / windows / esxi | hostname | service_ip |

inventory_hostname 으로 쓴 필드만 hostvars 에서 빠지고 나머지는 모두 남는다. 빈 문자열 필드도 키가 존재한다. 자세한 동작은 `inventory/my_inventory.sh` docstring 참고.

포털이 보낼지 보장 안 되는 필드는 `| default('')` 를 붙인다.

## 직접 실행

Jenkins 없이 돌릴 때:

```
ansible-playbook playbook/linux-ntp/site.yml --ask-vault-pass
```
