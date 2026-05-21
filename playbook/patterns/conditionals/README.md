# patterns/conditionals — 호스트나 상황에 따라 다르게 실행

같은 task 라도 호스트마다 다르게 동작해야 할 때가 있다:

- RHEL 에선 `dnf`, Ubuntu 에선 `apt` 로 패키지 설치 (패키지 매니저가 다름)
- 메모리 큰 서버에만 빠른 모드 활성화
- prod 환경에서만 슬랙 알림 보내기

task 옆에 `when:` 키워드를 붙이면 "**이 조건이 참일 때만 실행**" 이 된다. 조건이 거짓이면 그 task 는 그냥 skip (안 돌고 넘어감).

## 동작 흐름

```yaml
- name: RedHat 계열에서만 실행
  ansible.builtin.debug:
    msg: "RHEL 계열입니다"
  when: ansible_facts.os_family == 'RedHat'
```

`gather_facts: true` 가 필수다. 호스트 정보(OS, 메모리, CPU 등) 를 미리 수집해야 조건을 평가할 수 있다.

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

호스트 종류에 따라 어떤 task 는 실행되고 어떤 건 `skipping` 으로 표시된다. RHEL 9 호스트에서 돌리면 "RHEL 9 x86_64 환경" task 까지 다 통과한다.

## `when:` 의 흔한 모양

| 쓰임             | 예시                                              |
|:-----------------|:--------------------------------------------------|
| 단일 조건        | `when: 변수 == 값`                                |
| AND 여러 조건    | `when:` 아래 리스트로 — 모두 참이어야 실행        |
| OR               | `when: 조건A or 조건B`                            |
| 부정             | `when: not 조건`, `when: 값 not in [...]`         |
| 변수가 정의됐는지 | `when: my_var is defined`                         |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/` — `os_family == 'RedHat'` / `== 'Debian'` 으로 dnf/apt 분기
- `sandbox/` 의 `pre.yml` — RHEL 9 인지 확인하고 통과한 호스트만 다음 단계로
