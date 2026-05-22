# patterns/assert-fail — 시작 전에 조건을 검증하고, 필요하면 멈추기

`assert` 와 `fail` 은 playbook 을 "안전하게 멈추는" 두 모듈이다.
`assert` 는 조건이 거짓일 때만 멈추는 검증, `fail` 은 task 가 실행되면 무조건 멈추는 중단이다.

## 왜 필요한가

운영 자동화에서는 잘못된 환경에서 playbook 을 돌리는 사고가 가장 무섭다.
prod 전용 작업을 dev 호스트에서 돌렸다거나, 필수 변수를 빼먹은 채 실행했다거나 하는 식이다.
이런 사고는 본 작업이 시작되기 전 첫 단계에서 멈추도록 만들면 피해가 없다.
`assert` 는 "조건이 맞는지 검사하는 카메라" 처럼, `fail` 은 "여기까지 왔으면 끝" 의 브레이크처럼 동작한다.
Jenkins stage 진입 직전에 `if [ -z "$ENV" ]; then exit 1; fi` 를 박아두던 패턴이 그대로 옮겨온다.

## 먼저 알아둘 말

- `assert.that` — 검사할 조건을 리스트로 적는다. 하나라도 거짓이면 task 가 실패한다.
- `fail_msg` / `success_msg` — `assert` 실패 / 성공 시 보여줄 메시지다.
- `fail` 모듈 — 실행되면 무조건 task 를 실패시킨다. 보통 `when:` 과 같이 써서 "조건에 걸리면 중단" 형태로 쓴다.
- `-e env=값` — 명령줄에서 변수를 덮어쓰는 방법이다.

## 최소 예제

`env` 변수가 비어있지 않은지 먼저 검사한다.

```yaml
- name: env 변수가 비어있지 않은지 검증
  ansible.builtin.assert:
    that:
      - env | length > 0
    fail_msg:    "필수 변수 env 가 비어 있음 — -e env=dev|staging|prod 로 전달 필요"
    success_msg: "env={{ env }} 확인 완료"
```

`env` 가 빈 문자열이면 `fail_msg` 가 출력되고 task 가 실패한다.
값이 있으면 `success_msg` 가 출력되고 다음 task 로 넘어간다.

## 전체 예제 흐름

`site.yml` 은 검증 두 단계 + 명시적 중단 + 본 작업 흐름이다.

```yaml
- name: env 변수가 비어있지 않은지 검증 (assert)
  ansible.builtin.assert:
    that: [env | length > 0]
    fail_msg: "필수 변수 env 가 비어 있음"

- name: env 가 허용된 값 중 하나인지 검증
  ansible.builtin.assert:
    that: [env in ['dev', 'staging', 'prod']]
    fail_msg: "env 값이 유효하지 않음 (dev/staging/prod, 현재: {{ env }})"

- name: prod 환경이 아니면 명시적 중단 (fail)
  ansible.builtin.fail:
    msg: "이 playbook 은 prod 전용 — 현재 env={{ env }}"
  when: env != 'prod'

- name: 모든 검증 통과 후의 본 작업
  ansible.builtin.debug:
    msg: "검증 통과 — env={{ env }} 환경에서 실제 작업 실행 가능"
```

실행 순서는 다음과 같다.

1. 첫 번째 `assert` 가 `env` 가 비어있지 않은지 본다.
2. 통과하면 두 번째 `assert` 가 `env` 가 허용 값(`dev`/`staging`/`prod`)인지 본다.
3. 통과하면 `fail` 이 `env != 'prod'` 일 때만 실행되어 task 를 실패시킨다.
4. 그 외에는 마지막 `debug` 가 실행된다.
5. 어느 단계에서든 실패가 나면 그 호스트에서는 그 다음 task 가 실행되지 않는다.

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

같은 playbook 을 네 가지 입력으로 돌려보면 각 단계에서 멈추는 위치가 다르다.

```bash
# 1) env 안 줌 → 첫 assert 에서 멈춤
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/assert-fail/site.yml

# 2) 허용 안 된 값 → 두 번째 assert 에서 멈춤
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/assert-fail/site.yml -e env=production

# 3) 허용된 값이지만 prod 아님 → fail 에서 멈춤
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/assert-fail/site.yml -e env=dev

# 4) 전부 통과 → 본 작업까지 진입
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/assert-fail/site.yml -e env=prod
```

### 기대 결과 (4번 케이스)

```text
TASK [env 변수가 비어있지 않은지 검증] *****************
ok: [rhel9-dev-01] => {
    "msg": "env=prod 확인 완료"
}

TASK [prod 환경이 아니면 명시적 중단] *****************
skipping: [rhel9-dev-01]

TASK [모든 검증 통과 후의 본 작업] *********************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 검증 통과 — env=prod 환경에서 실제 작업 실행 가능"
}

PLAY RECAP **********************************************
rhel9-dev-01 : ok=3 changed=0 skipped=1 failed=0
```

## 두 번째 실행에서 볼 것

같은 입력으로 다시 돌리면 모든 task 가 같은 위치에서 같은 결과로 끝난다.
`assert` 와 `fail` 모두 시스템 상태를 바꾸지 않으므로 `changed=0` 이 그대로 유지된다.
"입력만으로 통과 여부가 결정된다" 는 점에서 멱등하다 — 본 작업이 들어 있는 실제 playbook 이라면, 검증을 통과한 호스트에서만 두 번째 실행에서도 그대로 본 작업이 실행된다.

## 자주 쓰는 모양

| 상황 | 모듈 + 조건 |
|---|---|
| 필수 변수 누락 검사 | `assert: that: [my_var is defined and my_var \| length > 0]` |
| 값 범위 검사 | `assert: that: [port \| int > 0, port \| int < 65536]` |
| 화이트리스트 검사 | `assert: that: [env in ['dev', 'staging', 'prod']]` |
| OS 가 RHEL 9 인지 검증 | `assert: that: [ansible_facts.distribution_major_version == '9']` |
| 디스크 여유 확인 | `assert: that: [free_kb \| int > 1048576]` (1 GB 이상) |
| 환경별 분기 후 중단 | `fail: msg=...` + `when: env != 'prod'` |
| 메시지만 다르게 | `fail_msg`, `success_msg` 둘 다 지정 |

## 두 모듈의 차이 한 줄 정리

| 모듈 | 언제 멈추나 | 자주 쓰이는 옵션 |
|---|---|---|
| `assert` | `that:` 의 조건 중 하나라도 거짓일 때 | `fail_msg`, `success_msg` |
| `fail` | task 가 실행되면 무조건 | `msg` (대개 `when:` 과 같이 사용) |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/pre.yml` — 업데이트 시작 전에 루트 파티션에 1 GB 이상 여유가 있는지 검증한다.
- `tasks/linux/pkg-update/post.yml` — 업데이트 후 sshd 가 active 인지 검증한다.
- `tasks/linux/sshd-safe-reload/` — 설정 변경 전후로 검증 task 가 들어간다.
- `sandbox/user01/pre.yml` — RHEL 9 환경인지 검증해 다른 OS 에서는 본 작업이 시작되지 않게 한다.
