# patterns/assert-fail — 사전 조건 검증과 명시적 중단

`ansible.builtin.assert` 로 **사전 조건을 검사**하고, `ansible.builtin.fail` 로 **조건이 안 맞으면 명시적으로 중단**하는 패턴. 잘못된 환경에서 playbook 이 끝까지 실행되는 사고를 막는다.

## 데모 시나리오

`env` 변수가:
1. 비어있지 않은지 (`assert`)
2. dev / staging / prod 중 하나인지 (`assert`)
3. prod 가 아니면 `fail` 로 중단

`-e env=prod` 로 실행해야 통과. 다른 값이면 단계별로 다른 에러 메시지가 나온다.

## assert vs fail 차이

| 모듈                | 트리거                                  | 메시지 옵션                              |
|:--------------------|:----------------------------------------|:-----------------------------------------|
| `assert`            | `that:` 조건이 **false** 일 때만 실패   | `fail_msg` + `success_msg`               |
| `fail`              | task 가 실행되면 **무조건** 실패        | `msg` 만 (보통 `when:` 과 조합)          |

- `assert` 는 "조건 검증 + 메시지 출력" — 검증 코드
- `fail` 은 "명시적으로 멈춰" — 분기 후 중단

## 언제 쓰나

- **playbook 시작 시 환경 / 변수 검증** — 잘못된 값이면 첫 task 에서 끊기
- **외부 명령 결과가 이상하면 중단** — `register` + `assert that: result.rc == 0`
- **위험한 환경 (prod) 에서 실수로 돌리는 것을 막기**
- **여러 가능성 중 하나만 허용해야 할 때** — `that: var in ['a', 'b', 'c']`

## 실제 작업에서 같은 패턴 보기

- [`tasks/linux/pkg-update/pre.yml`](../../tasks/linux/pkg-update/pre.yml) — 루트 파티션 1 GB 이상 여유 검증
- [`tasks/linux/pkg-update/post.yml`](../../tasks/linux/pkg-update/post.yml) — sshd active 검증
- [`sandbox/`](../../sandbox/) 의 `pre.yml` — RHEL 9 환경 assert
