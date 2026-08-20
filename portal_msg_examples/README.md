# portal_msg_examples

ClovirONE Portal 이 Jenkins Console Log 에서 `PORTAL_MSG` 를 파싱하는 방식을 검증하기 위한 예제 모음.

같은 점검 내용을 **출력 단위만 바꿔서** 4가지로 만들었다. Portal 파서가 어떤 형태를 받을지 결정하는 데 쓴다.

## 4가지 케이스

| 디렉터리 | 출력 단위 | Console Log 의 PORTAL_MSG 줄 수 | JSON 최상위 |
| :--- | :--- | :--- | :--- |
| `1_single/` | 결과 1건 = 1줄 | 9줄 (호스트 3 × Role 3 × Task 1) | 객체 |
| `2_per_host/` | 호스트 × Playbook 당 1줄 | 9줄 (호스트 3 × Playbook 3) | 배열 (2건) |
| `3_per_playbook/` | Playbook 당 1줄 | 3줄 | 배열 (6건) |
| `4_all_in_one/` | 실행 전체에 1줄 | 1줄 | 배열 (18건) |

`1_single` 은 Role 당 Task 1개, 나머지 3개는 배열이 의미를 갖도록 Role 당 Task 2개다.

## PORTAL_MSG 스키마

4가지 모두 레코드 1건의 필드는 동일하다. 배열 케이스는 이 객체를 배열로 감쌀 뿐, 필드를 추가하지 않는다.

| 필드 | 설명 |
| :--- | :--- |
| `timestamp` | `YYYYMMDDHHMMSS` |
| `host_name` | `inventory_hostname` |
| `host_addr` | `ansible_host` |
| `role_name` | 실행 중인 Role 이름 |
| `task_name` | 점검 항목 이름 |
| `original_value` | 점검 대상의 기존 값. 개념이 없으면 `null` (필드 자체는 항상 존재) |
| `return_code` | `PASS` / `FAIL` — register 한 실제 rc 로 결정 |
| `return_message` | 명령 출력 (실패 시 stderr) |

출력 형태:

```
PORTAL_MSG: {"timestamp":"...","host_name":"...", ...}      # 1_single
PORTAL_MSG: [{"timestamp":"...", ...}, {...}]               # 2, 3, 4
```

## 점검 항목

| Role | Task (`task_name`) | `original_value` |
| :--- | :--- | :--- |
| `portal_os_check` | `Check timezone` | 타임존 문자열 |
| | `Check kernel version` | 커널 버전 (1_single 에는 없음) |
| `portal_system_check` | `Check hostname` | 호스트명 |
| | `Check disk usage` | 루트 파일시스템 사용률 (1_single 에는 없음) |
| `portal_verify` | `Check uptime` | `null` |
| | `Check sshd status` | `active` / `inactive` (1_single 에는 없음) |

## 케이스별 구현 방식

**1_single** — Role 안에서 Task 결과마다 `debug` 로 바로 출력.

**2_per_host** — Role 이 `set_fact: portal_records` 로 배열을 만들고, Role 마지막에 호스트별로 출력. 호스트끼리 취합하지 않으므로 추가 장치가 없다.

**3_per_playbook** — Role 은 `portal_records` 를 만들기만 하고, Playbook 의 `post_tasks` 에서 `run_once` + `hostvars` 로 전 호스트분을 모아 1줄로 출력.

**4_all_in_one** — `ansible-playbook` 이 3번 따로 실행되므로 메모리로는 취합이 안 된다. 각 Role 이 결과를 `delegate_to: localhost` 로 Jenkins agent 의 `$PORTAL_MSG_DIR` 에 JSON 파일로 저장하고, 마지막 `04_emit.yml` 이 파일을 이름순으로 읽어 배열 1건으로 출력한다. 파일명은 `{seq}__{role}__{host}.json` 이라 정렬하면 실행 순서가 된다.

## Jenkins 설정

4개 모두 동일하다. 기존 `example-provisioning-portal-notify` Job 의 설정을 그대로 따른다.

- Agent: `label "${params.loc}"` (기본 `git`)
- Parameters: `loc`, `target_type`, `inventory_json`
- Environment: `INVENTORY_JSON`, `TARGET_TYPE`, `REPO_ROOT`, `ANSIBLE_ROLES_PATH` (+ 4번만 `PORTAL_MSG_DIR`)
- 인벤토리: `-i` 를 쓰지 않고, agent 의 `/etc/ansible/ansible.cfg` 에 설정된 `/opt/ansible-env/inventory/my_inventory.sh` 가 `INVENTORY_JSON` / `TARGET_TYPE` 를 읽는다
- Vault: `vaultCredentialsId: 'ansible-vault-password'` + Playbook 의 `vars_files: $REPO_ROOT/vault/linux.yml`
- Stage 는 케이스마다 1개 (`PORTAL MSG Parsing Test`)

`ANSIBLE_ROLES_PATH` 는 `roles/` 가 `playbooks/` 하위가 아니라서 필요하다.

## 파서가 알아야 할 것

Console Log 에 `PORTAL_MSG: {...}` 가 그대로 찍히지 않는다. `debug` 모듈을 쓰기 때문에 두 겹으로 감싸인다.

```
[0;32m    "msg": "PORTAL_MSG: {\"timestamp\": \"20260820113546\", ...}"[0m
```

1. `colorized: true` 로 인한 ANSI 컬러 코드
2. Ansible `debug` 의 `"msg": "..."` 안에 들어가면서 JSON 문자열로 escape (`"` → `\"`, 개행 → `\n`)

따라서 파서는 **ANSI 제거 → `msg` 값 추출 → unescape → JSON 파싱** 순서가 필요하다.

ANSI 만이라도 없애려면 Jenkinsfile 의 `colorized` 를 `false` 로 두면 된다. escape 까지 없애려면 `debug` 대신 custom callback plugin 이 필요한데, 이 저장소에는 아직 callback 이 없다.
