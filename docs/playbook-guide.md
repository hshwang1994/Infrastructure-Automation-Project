# Playbook 가이드

실제 예시는 `playbook/tasks/linux/` 안의 각 작업 디렉토리 site.yml 참고. Ansible 문법 패턴(roles, block/rescue, tags) 자체를 보고 싶다면 `playbook/patterns/`.

## 기본값 (linux target_type)

| connection | gather_facts | become       | vault 파일           |
| :--------- | :----------: | :----------- | :------------------- |
| ssh        | true         | true (sudo)  | `vault/linux.yml`    |

`gather_facts` 는 OS 가 아직 살아있지 않은 상태(킥스타트 직후 등) 에서는 `false` 로 둔다. setup 모듈이 OS 정보를 못 받아오면 시간만 낭비.

## 필수 구조

```yaml
- hosts: all
  connection: ssh
  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
  tasks:
    - ...
```

### 각 줄이 왜 그렇게 쓰여 있는지

- **`hosts: all`** 고정. `inventory/my_inventory.sh` 가 만드는 인벤토리는 그룹이 `all` 하나뿐이라, 다른 패턴을 적으면 0대 매칭됨.
- **`vars_files` 의 `vault/linux.yml`** — ansible-playbook 실행 시 자동 복호화되어, 그 안에 들어있는 `ansible_user`, `ansible_password`, `ansible_become_password`, `ansible_ssh_common_args` 가 playbook 변수로 들어온다. SSH 연결할 때 ansible 이 자동으로 사용함.

## 포털이 보낸 값을 playbook 에서 쓰는 법

포털은 작업마다 이런 JSON 을 보낸다:

```json
[{"service_ip": "10.0.2.1", "hostname": "WEB-01", "vendor": "dell"}]
```

`inventory/my_inventory.sh` 가 이걸 받아서 ansible 한테 두 가지를 정해준다.

### 1. 호스트의 이름과 접속 IP

- **이름** (`inventory_hostname`): 로그에 `[WEB-01]` 처럼 찍히는 식별자 = `hostname` 값
- **접속 IP** (`ansible_host`): 실제로 SSH 로 붙는 주소 = `service_ip` 값

playbook 에서:
- `{{ inventory_hostname }}` → 그 호스트의 "이름"
- `{{ hostvars[inventory_hostname]['ansible_host'] }}` → 접속 IP

### 2. 나머지 필드 (`vendor`, `mgmt_ip` 등) 꺼내기

포털이 보낸 다른 필드는 전부 `hostvars` 에 그대로 들어간다. 꺼내는 법:

```yaml
- debug:
    msg: "{{ hostvars[inventory_hostname]['vendor'] }}"
```

규칙 둘:

- **이름으로 쓴 필드는 hostvars 에서 빠진다.** `hostname` 이 `inventory_hostname` 자체로 이미 잡혀서 hostvars 에는 안 들어간다. 그 필드가 필요하면 `inventory_hostname` 으로 참조하면 됨.
- **포털이 그 필드를 항상 보낸다는 보장이 없으면** `| default('')` 를 붙여서 없을 때 빈 문자열로 대체:

  ```yaml
  "{{ hostvars[inventory_hostname]['mgmt_ip'] | default('') }}"
  ```

자세한 변환 동작은 `inventory/my_inventory.sh` 의 상단 docstring 에 입출력 예시와 함께 있다.

## 직접 실행 (Jenkins 없이 로컬에서)

```
ansible-playbook playbook/tasks/linux/ntp/site.yml --ask-vault-pass
```

`--ask-vault-pass` 가 vault 비밀번호를 인터랙티브로 묻는다. 자동화하려면 `--vault-password-file <파일>` 또는 `ANSIBLE_VAULT_PASSWORD_FILE` 환경변수.
