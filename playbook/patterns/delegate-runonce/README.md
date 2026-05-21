# patterns/delegate-runonce — delegate_to · run_once

특정 task 를 **다른 호스트에서 실행** (`delegate_to`) 하거나 **inventory 전체에 대해 단 한 번만 실행** (`run_once`) 하는 패턴. 두 키워드는 자주 같이 쓰인다.

## 데모 시나리오

1. `delegate_to: localhost` + `run_once: true` 로 **컨트롤러에서 한 번** 현재 시각을 받아옴
2. 받아온 값을 모든 타겟에서 같은 값으로 사용 (각자 다른 시각이 아니라 한 시점)
3. `run_once: true` 단독 사용 — 한 호스트만 메시지 출력
4. 비교용으로 일반 task 도 함께 (모든 호스트가 각자 실행)

## delegate_to 의 흔한 활용

| 패턴                                         | 무엇                                                                       |
|:---------------------------------------------|:---------------------------------------------------------------------------|
| `delegate_to: localhost`                     | 컨트롤러에서 API 호출 · DNS 등록 · curl 으로 외부 응답 확인               |
| `delegate_to: "{{ groups['db'][0] }}"`       | DB 호스트에서만 백업 / 마이그레이션 실행                                  |
| `delegate_to: "{{ ansible_play_hosts[0] }}"` | 첫 번째 호스트에서만 작업 (run_once 와 같이 자주)                          |

## run_once 의 흔한 활용

- **한 번만 알림 보내기** — 슬랙 / 이메일 (호스트마다 보내면 안 됨)
- **잠금 획득 / 해제** — 분산 잠금
- **공통 자원 생성** — 한 클러스터의 shared 리소스

## delegate_facts

`delegate_to` 한 task 의 facts 를 위임 대상의 facts 로 저장하려면 `delegate_facts: true` 필요. 이 옵션 없이는 facts 가 원래 호스트의 컨텍스트에 저장된다.

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/sshd-safe-reload/`](../../tasks/linux/sshd-safe-reload/) — `wait_for: port: 22` 를 `delegate_to: localhost` 로 컨트롤러에서 검사 (타겟이 응답 못 하면 컨트롤러가 알아챔).
