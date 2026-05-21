# patterns/delegate-runonce — 다른 호스트에서 실행 / 한 번만 실행

기본적으로 task 는 inventory 의 **각 호스트에서 한 번씩** 실행된다. 하지만 가끔은 다르게 돌아야 한다:

- 슬랙 알림은 한 번만 보내야 함 — 호스트 100 대마다 알림 보내면 시끄러움
- 컨트롤러에서 API 호출 받아오기 — 타깃이 외부 인터넷 못 나가는 경우
- DB 마이그레이션은 DB 서버 하나에서만 — 여러 번 돌리면 사고

두 키워드가 이걸 해준다:

- `delegate_to: <호스트>` — 이 task 를 **그 호스트에서** 실행 (원래 대상 대신)
- `run_once: true` — inventory 전체에 대해 **단 한 번만** 실행

자주 같이 쓴다.

## 동작 흐름

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

첫 task 는 **컨트롤러에서 한 번** 만 실행, 결과는 모든 타깃이 공유. 두 번째 task 는 평소대로 각 타깃에서 실행되지만 모두 같은 값을 본다.

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

inventory 에 호스트 여러 대가 있으면 출력에서 흥미로운 점이 보인다:
- task 1 (delegate + run_once): 한 줄만 출력 — 어느 한 호스트의 컨텍스트로 한 번
- task 3 (run_once 만): 역시 한 줄만 — 한 호스트 담당으로 한 번
- task 4 (일반): 호스트 수만큼 출력

## `delegate_to` 의 흔한 활용

| 패턴                                         | 무엇을 하나                                                |
|:---------------------------------------------|:-----------------------------------------------------------|
| `delegate_to: localhost`                     | 컨트롤러에서 API 호출 · DNS 등록 · curl 로 외부 응답 확인  |
| `delegate_to: "{{ groups['db'][0] }}"`       | DB 호스트에서만 백업 · 마이그레이션                        |
| `delegate_to: "{{ ansible_play_hosts[0] }}"` | 첫 번째 호스트에서만 (run_once 와 같이)                    |

## `run_once` 의 흔한 활용

- 슬랙 / 이메일 알림 (호스트마다 보내면 안 됨)
- 분산 잠금 획득·해제
- 클러스터의 공유 리소스 생성

## 실제 작업에서 어디 쓰이나

`tasks/linux/sshd-safe-reload/` — sshd 재시작 후 22 포트 응답 확인을 `wait_for + delegate_to: localhost` 로 한다. 타깃이 sshd 변경 때문에 끊겨도 컨트롤러에서 검사하니까 확인이 가능.
