# sandbox/user06 — 연습용 슬롯

Jenkins 에 등록해서 실제로 돌려보고, 각 yml 파일을 하나씩 수정하면서 Ansible / Jenkins 흐름을 익혀보는 자리.

같은 내용의 슬롯 10개 (`user06` ~ `user10`) 가 있다. 다른 사람과 충돌나지 않게 **본인 슬롯만 수정**하면 됨.

## 대상

RHEL 9 (9.10) Linux. `pre.yml` 의 assert 가 RHEL 9 이 아니면 fail 시켜서 환경 실수 방지.

## 3 stage 구성

| stage        | playbook   | 무엇을 |
|--------------|------------|--------|
| Pre-check    | `pre.yml`  | RHEL 9 환경 검증 + 호스트 정보 (OS, kernel, CPU, MEM) 출력 |
| Main         | `main.yml` | `/tmp/practice.txt` 에 메시지 + 타임스탬프 작성 |
| Post-verify  | `post.yml` | 파일 존재 확인 → 내용 다시 읽어 출력 |

세 stage 모두 RHEL 9 호스트면 안전하게 멱등 (`/tmp/` 영역만 건드림). 반복 실행 OK.

## 어디를 수정해보면 좋을지

연습 아이디어 (어렵지 않은 순):

1. **`main.yml` 의 `vars:` 블록** — `practice_message` 를 본인 이름·메시지로 변경
2. **`main.yml` 의 task** — `ansible.builtin.copy` → `ansible.builtin.lineinfile` 로 바꿔서 한 줄씩 append 되게 만들기
3. **`pre.yml` 의 assert** — RHEL 8 도 허용하게 조건 완화
4. **`post.yml` 의 slurp** — `slurp` 대신 `ansible.builtin.command: cat ...` + `register` 로 바꿔보기
5. **`Jenkinsfile`** — `Pre-check` 와 `Main` 사이에 stage 하나 추가 (예: `Lint` 으로 `ansible-playbook --syntax-check` 호출)
6. **모듈 교체** — `copy` 를 `template` 으로 바꾸고 `templates/practice.j2` 만들기
7. **handler 추가** — `main.yml` 에서 파일이 바뀌었을 때만 `notify` 로 debug 메시지 출력

## Jenkins 에 등록하기

1. Pipeline 타입 job 새로 만들기
2. Pipeline → Definition: **Pipeline script from SCM**
3. SCM: Git, Repo: 이 저장소
4. Script Path: `playbook/sandbox/user06/Jenkinsfile`
5. Save → Build with Parameters (loc / target_type / inventory_json 입력)

## 주의

- `vault/linux.yml` 자격증명이 이미 구성돼 있어야 함 (저장소 README 참고)
- `inventory_json` 에는 RHEL 9 호스트만 포함시킬 것
- 이 슬롯은 작업용이 아니라 **연습용**. 운영 호스트 직접 가리키지 말 것
