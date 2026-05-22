# patterns/import-include — task 파일을 여러 개로 쪼개 부르기

`import_tasks` 와 `include_tasks` 는 task 들을 별도 yml 파일로 빼서 메인 playbook 에서 불러오는 두 방법이다.
정적/동적이라는 한 가지 결정적 차이가 있고, 이 차이가 `loop:` 같이 쓸 수 있는지를 가른다.

## 왜 필요한가

운영 자동화에서는 한 playbook 에 task 가 점점 쌓이다가 100 줄을 넘으면 한눈에 들어오지 않는다.
같은 task 묶음을 다른 playbook 에서도 쓰고 싶거나, env 별로 같은 흐름을 살짝씩 다르게 부르고 싶을 때도 있다.
task 들을 따로 yml 파일로 빼두고 메인에서 호출하면 가독성과 재사용성이 동시에 좋아진다.
부르는 방식은 두 가지 — `import_tasks` 와 `include_tasks` — 이고, 각각 정적·동적 평가 시점이 달라 쓰임이 다르다.
Jenkins shared library 의 `load` 와 함수 호출의 차이라고 보면 감이 잡힌다.

## 먼저 알아둘 말

- `import_tasks` — 정적, playbook 을 파싱하는 시점에 그 자리에 task 들이 합쳐진다.
- `include_tasks` — 동적, 실행 도중 그 task 를 만났을 때 평가되어 합쳐진다.
- `loop_control: loop_var` — `item` 대신 다른 이름으로 받고 싶을 때 쓰는 옵션이다.

## 최소 예제

같은 yml 파일을 정적/동적 두 방식으로 부른다.

```yaml
- name: 정적 import — playbook 파싱 시 합쳐짐
  ansible.builtin.import_tasks: imported.yml

- name: 동적 include — 실행 도중 평가
  ansible.builtin.include_tasks: included.yml
  loop: [dev, prod]
  loop_control:
    loop_var: env_name
```

`import_tasks` 는 `imported.yml` 의 task 들이 그 자리에 펼쳐진 것처럼 동작한다.
`include_tasks` 는 `loop:` 와 같이 쓸 수 있어, `included.yml` 이 `env_name=dev`, `env_name=prod` 두 번 실행된다.

## 전체 예제 흐름

이 데모의 디렉토리 구조는 다음과 같다.

```
import-include/
├── site.yml         메인 play (두 방식 다 호출)
├── imported.yml     import_tasks 로 가져올 task 모음
└── included.yml     include_tasks 로 loop 와 함께 부를 task 모음
```

`imported.yml` 은 단순한 task 두 개다.

```yaml
- name: imported — 시작 알림
  ansible.builtin.debug:
    msg: "import_tasks 로 합쳐진 task 실행 중"

- name: imported — uptime 받아오기
  ansible.builtin.command: uptime
  register: up
  changed_when: false
```

`included.yml` 은 변수 `env_name` 을 받아서 동작한다.

```yaml
- name: included — env 별 시작 알림
  ansible.builtin.debug:
    msg: "include_tasks 로 env={{ env_name }} 동작 시작"

- name: included — env 별 파일 생성
  ansible.builtin.copy:
    content: "this is {{ env_name }} config\n"
    dest:    "/tmp/include-demo-{{ env_name }}.conf"
    mode:    '0644'
```

실행 순서는 다음과 같다.

1. `site.yml` 이 `import_tasks: imported.yml` 을 만나면 그 자리에 두 task 가 펼쳐진다.
2. uptime 조회 결과가 표시된다.
3. 다음 `include_tasks: included.yml` 을 `loop: [dev, prod]` 와 함께 호출한다.
4. `env_name=dev` 로 한 번, `env_name=prod` 로 한 번, 총 두 번 실행된다.
5. 각각 `/tmp/include-demo-dev.conf` 와 `/tmp/include-demo-prod.conf` 가 만들어진다.

## 직접 돌려보기

### 실행 전 확인

- 대상 서버: Linux (RHEL 9 계열)
- Ansible: 2.15 이상
- 동적 인벤토리: `inventory/my_inventory.sh`
- 환경변수:
  ```bash
  export TARGET_TYPE=linux
  export INVENTORY_JSON='[{"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"}]'
  ```

```bash
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/import-include/site.yml
```

### 기대 결과

```text
TASK [imported — 시작 알림] **************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: import_tasks 로 합쳐진 task 실행 중"
}

TASK [imported — uptime 결과 출력] ***********************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: uptime = 09:31:22 up 3 days,  4:21,  1 user, load average: 0.04, 0.05, 0.06"
}

TASK [included — env=dev 처리 시작] *********************
ok: [rhel9-dev-01]

TASK [included — env 별로 다른 파일 생성] ****************
changed: [rhel9-dev-01]

TASK [included — env=prod 처리 시작] ********************
ok: [rhel9-dev-01]

TASK [included — env 별로 다른 파일 생성] ****************
changed: [rhel9-dev-01]
```

`included.yml` 의 task 두 개가 `env_name` 값을 바꿔가며 두 번씩 등장한다.

## 자주 쓰는 모양

| 상황 | 방식 |
|---|---|
| 큰 playbook 을 단순히 task 파일로 분리 | `import_tasks: tasks_part1.yml` |
| env 별로 같은 흐름을 반복 | `include_tasks: env-task.yml` + `loop:` |
| 변수로 파일명 결정 | `include_tasks: "{{ env_name }}.yml"` |
| 조건이 거짓이면 통째로 skip | `include_tasks: ... when: env == 'prod'` |
| 사전에 `--list-tasks` 로 전체 보기 | `import_tasks` (정적, list 에 잡힘) |
| role 안 `tasks/main.yml` 분기 | role 의 `main.yml` 안에서 `include_tasks` 로 OS 별 파일 분기 |

## 두 방식의 차이 한눈에

| 항목 | `import_tasks` (정적) | `include_tasks` (동적) |
|---|---|---|
| 평가 시점 | playbook 파싱 시 | 실행 도중 |
| `loop:` 와 같이 쓰기 | 불가 | 가능 |
| `when:` 동작 | 안쪽 모든 task 에 적용 | include 자체에 적용 (거짓이면 통째로 skip) |
| 변수로 파일명 지정 | 제한적 | 자유롭게 (`{{ env_name }}.yml`) |
| `--list-tasks` 출력 | 안쪽 task 도 모두 표시 | include 안쪽 task 는 표시 안 됨 |
| 사용 시점 결정 기준 | 코드 분리 / 재사용만 필요할 때 | 동적으로 파일을 골라 부르거나 반복이 필요할 때 |

## 선택 기준 한 줄

- 단순히 코드를 나누고 재사용만 하고 싶다 → `import_tasks`
- `loop:` 과 같이 쓰거나 변수로 파일명을 정하고 싶다 → `include_tasks`

## 막힐 때 확인

> 증상: `import_tasks` 에 `loop:` 를 붙였더니 에러가 난다.
>
> 확인할 것:
> - `import_tasks` 는 정적이라 `loop:` 와 같이 쓸 수 없다. `include_tasks` 로 바꿔야 한다.
> - 반대로 정적 합치기를 유지하면서 반복을 표현하려면 `imported.yml` 안에서 `loop:` 를 쓰는 식으로 안쪽으로 옮긴다.

> 증상: `--list-tasks` 를 했는데 `include_tasks` 안쪽 task 가 안 보인다.
>
> 확인할 것:
> - 정상이다. 동적 include 는 실행 시점에 평가되므로 사전 list 에는 잡히지 않는다.
> - 사전 미리보기가 꼭 필요하면 `import_tasks` 로 바꾸거나, 안쪽에 명시적 tag 를 넣는다.

## 실제 작업에서 어디 쓰이나

- `tasks/linux/baseline/` — role 안 `tasks/main.yml` 은 자동으로 import 된다. role 안 task 는 정적 import 컨벤션이다.
- `patterns/loops/` — `include_tasks` + `loop:` 를 같이 쓰는 패턴과 짝이 된다.
- `patterns/roles/` — `include_role` / `import_role` 도 같은 정적/동적 구분을 따른다.
