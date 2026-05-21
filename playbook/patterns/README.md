# patterns/ — Ansible 문법·구조 데모

`tasks/` 가 "**무엇을 하는가**" 라면 `patterns/` 는 "**Ansible 의 이 문법은 어떻게 생겼는가**" 를 보여주는 자리.

학습용이라 Jenkinsfile 없이 **작은 site.yml + README.md** 한 쌍으로만 구성. 실제 운영에서는 `tasks/` 안의 같은 패턴을 쓰는 예시를 복사해서 시작하면 된다.

## 데모 목록

| 디렉토리                                          | 보여주는 문법                                       | 실제 작업에서 같은 패턴을 쓰는 예시                                       |
| :------------------------------------------------ | :-------------------------------------------------- | :------------------------------------------------------------------------ |
| [`roles/`](roles/)                                | Role 디렉토리 구조 (`roles/{name}/{tasks,handlers,defaults,templates}`) | [`tasks/linux/baseline/`](../tasks/linux/baseline/)            |
| [`block-rescue/`](block-rescue/)                  | `block` → `rescue` → `always` 로 실패 시 자동 롤백  | [`tasks/linux/sshd-safe-reload/`](../tasks/linux/sshd-safe-reload/)       |
| [`tags/`](tags/)                                  | `tags` 로 같은 playbook 을 단계별 부분 실행          | [`tasks/linux/nginx-healthcheck/`](../tasks/linux/nginx-healthcheck/)     |
| [`handlers/`](handlers/)                          | `notify` + `handlers` — config 변경 시에만 service 재시작 | [`tasks/linux/nginx-healthcheck/`](../tasks/linux/nginx-healthcheck/) |
| [`conditionals/`](conditionals/)                  | `when:` 으로 OS family · 값 · 결과 기반 분기         | [`tasks/linux/pkg-update/`](../tasks/linux/pkg-update/)                   |
| [`loops/`](loops/)                                | `loop:` 로 여러 항목 반복 + `loop_control`           | (자주 쓰임 — 학습 데모로 시작)                                            |
| [`templates/`](templates/)                        | Jinja2 `template:` 모듈 + 변수 · 반복 · 필터          | [`tasks/linux/baseline/`](../tasks/linux/baseline/) (motd.j2)             |
| [`assert-fail/`](assert-fail/)                    | `assert` 로 사전 검증, `fail` 로 명시적 중단         | [`tasks/linux/pkg-update/`](../tasks/linux/pkg-update/), [`sandbox/`](../sandbox/) |
| [`register-when/`](register-when/)                | `register:` 로 결과 잡고 다음 task 의 `when:` 분기   | [`tasks/linux/pkg-update/post.yml`](../tasks/linux/pkg-update/post.yml)   |
| [`import-include/`](import-include/)              | `import_tasks` (정적) vs `include_tasks` (동적)      | role 의 `tasks/main.yml` 자동 import                                      |
| [`lookup/`](lookup/)                              | 컨트롤러에서 env · file · pipe 동적 조회             | 모든 playbook 의 `vars_files: "{{ lookup('env', 'REPO_ROOT') }}/..."`     |
| [`delegate-runonce/`](delegate-runonce/)          | `delegate_to` 로 다른 호스트, `run_once` 로 한 번만  | [`tasks/linux/sshd-safe-reload/`](../tasks/linux/sshd-safe-reload/)       |

## 직접 실행해보기

각 데모는 ansible-playbook 으로 단독 실행 가능 (인벤토리는 자유):

```
ansible-playbook -i inventory.ini playbook/patterns/{이름}/site.yml --ask-vault-pass
```

타겟에 변경을 일으키지 않거나, `/tmp` 같이 안전한 경로에만 쓰도록 작성돼 있다. 반복 실행 OK.

## 권장 학습 순서

처음 Ansible 을 접한다면 다음 순서:

1. **`handlers/`** — service 재시작 멱등성
2. **`conditionals/`** — OS / 값 / 결과 기반 분기
3. **`loops/`** — 반복 처리
4. **`register-when/`** — 결과 → 다음 분기
5. **`templates/`** — config 파일 생성
6. **`assert-fail/`** — 안전한 사전 검증
7. **`block-rescue/`** — 실패 시 롤백 (복합 패턴)
8. **`tags/`** — 단계별 실행 (Jenkins 다단계와 결합)
9. **`roles/`** — 코드 재사용 구조
10. **`import-include/`** — task 파일 분리
11. **`lookup/`** — 컨트롤러 측 동적 값
12. **`delegate-runonce/`** — 위임 / 한 번만
