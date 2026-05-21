# patterns/conditionals — when 으로 task 조건부 실행

`when:` 으로 task 를 **조건에 맞을 때만** 실행. OS family · 값 비교 · 여러 조건 AND 등 여러 형태가 가능하다.

## 데모 시나리오

호스트의 `ansible_facts` 를 보고:
1. OS family 별 분기 (RedHat / Debian / 그 외)
2. 메모리 크기 기준 분기 (≥ 8 GB / < 8 GB)
3. 여러 조건 AND (RHEL 9 + x86_64)

각 task 가 자기 조건에 맞는 호스트에서만 실행되고 나머지는 `skipping` 됨. `gather_facts: true` 필요 (facts 없이는 분기 불가).

## when 의 문법

- 단일 조건: `when: ansible_facts.os_family == 'RedHat'`
- 여러 조건 AND: `when:` 아래 리스트로 나열 (모두 true 여야 실행)
- 여러 조건 OR: `when: cond_a or cond_b` (인라인 표현식)
- 부정: `when: not <조건>`, `when: var not in [...]`
- 결과 값 비교: `when: register_var.rc != 0`

## 언제 쓰나

- **OS 별 다른 패키지 매니저** (dnf vs apt) — 가장 흔한 케이스
- **환경 별 다른 동작** (prod 만 슬랙 알림 보내기 등)
- **이전 task 의 결과**(register 값) 에 따라 다음 task 분기
- **변수 존재 여부 검증** (`when: my_var is defined`)

## 실제 작업에서 같은 패턴 보기

- [`tasks/linux/pkg-update/`](../../tasks/linux/pkg-update/) — `os_family == 'RedHat'` / `== 'Debian'` 으로 `dnf` / `apt` 분기
- [`tasks/linux/pkg-update/post.yml`](../../tasks/linux/pkg-update/post.yml) — `assert that:` 로 service 상태 분기
