# patterns/delegate-runonce — 다른 호스트에서 실행 / 인벤토리 전체에서 한 번만 실행

`delegate_to` 는 그 task 를 다른 호스트에서 실행하게 만든다.
`run_once` 는 인벤토리 전체에서 그 task 가 단 한 번만 실행되게 만든다.

## 왜 필요한가

기본적으로 task 는 인벤토리의 각 호스트에서 한 번씩 실행된다.
하지만 슬랙 알림을 100 대에 한 번씩 보내면 시끄럽고, DB 마이그레이션을 모든 호스트에서 돌리면 사고가 난다.
타깃이 외부 인터넷에 못 나갈 때, API 호출은 컨트롤러에서 대신 해줘야 하는 경우도 있다.
`delegate_to` 와 `run_once` 는 이런 "위치 / 횟수가 다르게 돌아야 하는 task" 를 표현하는 표준 도구다.
두 키워드는 자주 같이 쓰여 "어떤 호스트에서, 전체에서 몇 번" 을 한 번에 정한다.

## 먼저 알아둘 말

- `delegate_to: 호스트` — 원래 대상이 아닌 그 호스트에서 task 를 실행한다. `inventory_hostname` 변수 등은 원래 대상의 값을 유지한다.
- `delegate_to: localhost` — 컨트롤러 자체에서 실행한다. 외부 API 호출이나 알림에 자주 쓰인다.
- `run_once: true` — 같은 play 안에서 그 task 를 단 한 번만 실행한다. 담당 호스트는 보통 첫 번째다.
- `changed_when: false` — 조회 목적의 명령에 붙여 멱등성을 깨지 않게 한다.

## 최소 예제

컨트롤러에서 현재 시각을 한 번만 받아와, 모든 타깃이 같은 값을 공유한다.

```yaml
- name: 컨트롤러에서 현재 시각 받아오기 (한 번만)
  ansible.builtin.command: date "+%Y-%m-%dT%H:%M:%S"
  register: ctrl_time
  delegate_to: localhost
  run_once: true
  changed_when: false

- name: 받아온 시각을 모든 타깃이 같은 값으로 사용
  ansible.builtin.debug:
    msg: "컨트롤러 시각 = {{ ctrl_time.stdout }}"
```

첫 task 는 컨트롤러에서 한 번만 돌고, 결과는 모든 타깃이 공유한다.
두 번째 task 는 평소대로 각 타깃에서 실행되며 모두 같은 값을 본다.

## 전체 예제 흐름

`site.yml` 은 delegate + run_once / run_once 단독 / 일반 task 흐름이다.

```yaml
tasks:
  - name: 1) 컨트롤러(localhost) 에서 현재 시각
    ansible.builtin.command: date "+%Y-%m-%dT%H:%M:%S"
    register: ctrl_time
    delegate_to: localhost
    run_once: true
    changed_when: false

  - name: 2) 받아온 시각을 모든 타깃에 전파
    ansible.builtin.debug:
      msg: "컨트롤러 시각 = {{ ctrl_time.stdout }}"

  - name: 3) 인벤토리 전체에 한 번만 실행
    ansible.builtin.debug:
      msg: "이 메시지는 단 한 번만 — 담당 호스트: {{ inventory_hostname }}"
    run_once: true

  - name: 4) 대조용 — 각 타깃에서 따로 실행
    ansible.builtin.debug:
      msg: "모든 호스트에서 따로 출력 — {{ inventory_hostname }}"
```

실행 순서는 다음과 같다.

1. task 1 이 컨트롤러에서 한 번 실행되어 `ctrl_time.stdout` 에 시각이 담긴다.
2. task 2 가 각 타깃에서 실행되며, 모든 호스트가 같은 `ctrl_time.stdout` 값을 본다.
3. task 3 은 인벤토리 전체 중 첫 호스트에서만 실행되어 한 줄만 출력된다.
4. task 4 는 일반 task 이므로 호스트 수만큼 출력이 늘어난다.

## 직접 돌려보기

### 실행 전 확인

- 대상 서버: Linux (RHEL 9 계열) — 여러 호스트를 등록하면 차이가 더 잘 보인다.
- Ansible: 2.15 이상
- 동적 인벤토리: `inventory/my_inventory.sh`
- 환경변수:
  ```bash
  export TARGET_TYPE=linux
  export INVENTORY_JSON='[
    {"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"},
    {"hostname":"rhel9-dev-02","service_ip":"192.168.0.11"}
  ]'
  ```

```bash
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/delegate-runonce/site.yml
```

### 기대 결과 (호스트 2 대 기준)

```text
TASK [1) 컨트롤러(localhost) 에서 현재 시각] **************
ok: [rhel9-dev-01 -> localhost]

TASK [2) 받아온 시각을 모든 타깃에 전파] *****************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 컨트롤러 시각 = 2026-..."
}
ok: [rhel9-dev-02] => {
    "msg": "rhel9-dev-02: 컨트롤러 시각 = 2026-..."
}

TASK [3) 인벤토리 전체에 한 번만 실행] *******************
ok: [rhel9-dev-01] => {
    "msg": "이 메시지는 단 한 번만 — 담당 호스트: rhel9-dev-01"
}

TASK [4) 대조용 — 각 타깃에서 따로 실행] ******************
ok: [rhel9-dev-01] => {"msg": "모든 호스트에서 따로 출력 — rhel9-dev-01"}
ok: [rhel9-dev-02] => {"msg": "모든 호스트에서 따로 출력 — rhel9-dev-02"}
```

task 1 옆의 `-> localhost` 가 delegate 표시다.
task 3 은 인벤토리 전체 중 한 줄만 나오고, task 4 는 호스트 수만큼 줄이 늘어난다.

## 자주 쓰는 모양

| 상황 | 키워드 조합 |
|---|---|
| 컨트롤러에서 외부 API 호출 | `delegate_to: localhost` |
| DB 호스트에서만 백업 | `delegate_to: "{{ groups['db'][0] }}"` + `run_once: true` |
| 첫 번째 호스트에서만 실행 | `delegate_to: "{{ ansible_play_hosts[0] }}"` + `run_once: true` |
| 알림 / 보고를 인벤토리 전체에 한 번 | `run_once: true` |
| delegate 호스트 fact 까지 가져오기 | `delegate_to: ...` + `delegate_facts: true` |
| 변경을 다른 호스트가 본 것처럼 표시 | `delegate_to: ...` + `register: ...` 사용 |

## 막힐 때 확인

> 증상: `delegate_to` 가 안 먹히고 원래 호스트에서 그대로 실행된다.
>
> 확인할 것:
> - 위임 대상 호스트가 인벤토리 또는 `ansible_connection: local` 로 도달 가능한지 확인한다.
> - `delegate_to: localhost` 인데 SSH 로 자기 자신에게 접속하려 한다면 인벤토리에 `localhost ansible_connection=local` 을 두면 깔끔하다.

> 증상: `run_once: true` 인데 호스트 수만큼 출력된다.
>
> 확인할 것:
> - `run_once` 는 같은 play 단위에서만 한 번을 보장한다. 같은 task 가 여러 play 에 들어 있으면 play 마다 한 번씩 돈다.
> - serial 옵션이나 strategy 설정에 따라 동작이 달라질 수 있다.

## 실제 작업에서 어디 쓰이나

- `tasks/linux/sshd-safe-reload/` — sshd 재시작 후 22 포트 응답 확인을 `wait_for + delegate_to: localhost` 로 한다. 타깃이 sshd 변경 때문에 잠시 끊겨도 컨트롤러에서 검사하므로 확인할 수 있다.
- `patterns/register-when/` — `delegate_to + register` 로 컨트롤러에서 얻은 값을 다음 task 의 `when:` 에 쓰는 흐름.
- `patterns/handlers/` — `run_once: true` 가 붙은 handler 로 알림성 후속 task 를 인벤토리 전체에 한 번만 보내는 패턴.
