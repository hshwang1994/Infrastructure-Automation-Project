# sandbox/ — 연습용 슬롯

`tasks/` 가 실제 운영 작업, `patterns/` 가 문법 데모라면, `sandbox/` 는 **사용자가 직접 들어와서 yml 을 하나씩 수정해보면서 익히는 연습장**.

## 슬롯 구조

`user01/` ~ `user10/` 까지 **10개 슬롯이 모두 동일한 내용**으로 들어 있다. 1인 1슬롯 점유하면 다른 사람과 충돌 없이 자유롭게 수정 가능.

각 슬롯 안 (`user01/` 기준):

```
user01/
├── Jenkinsfile     3 stage (Pre-check / Main / Post-verify)
├── pre.yml         RHEL 9 환경 검증 + 호스트 정보 출력
├── main.yml        /tmp/practice.txt 작성
├── post.yml        파일 다시 읽어 내용 출력
└── README.md       슬롯 안내 (이 파일의 짧은 stub)
```

## 대상

**RHEL 9 (9.10) Linux** 만. `pre.yml` 의 assert 가 RHEL 9 이 아니면 fail 시켜서 환경 실수 방지.

## 3 stage 구성

| stage         | playbook    | 내용                                                            |
| :------------ | :---------- | :-------------------------------------------------------------- |
| Pre-check     | `pre.yml`   | RHEL 9 환경 검증 + 호스트 정보 (OS, kernel, CPU, MEM) 출력      |
| Main          | `main.yml`  | `/tmp/practice.txt` 에 메시지 + 타임스탬프 작성                 |
| Post-verify   | `post.yml`  | 파일 존재 확인 → 내용 다시 읽어 출력                            |

세 stage 모두 RHEL 9 호스트면 안전하게 멱등 (`/tmp/` 영역만 건드림). 반복 실행 OK.

## 왜 3 stage 인가

Jenkins 의 다단계 pipeline 흐름까지 같이 익히기 위함. 단일 stage 로 충분한 단순 작업도 일부러 **Pre / Main / Post** 로 쪼개서, "stage 사이에 검증·롤백을 끼우는 감각" 을 연습할 수 있게 했다.

## 사용 흐름

1. 본인 슬롯 하나 정함 (예: `user03`)
2. Jenkins Pipeline job 만들고 Script Path: `playbook/sandbox/user03/Jenkinsfile`
3. 일단 그대로 한 번 돌려서 성공 확인
4. yml 을 하나씩 수정해보면서 변화 관찰

## Jenkins 에 등록하기

1. Pipeline 타입 job 새로 만들기
2. Pipeline → Definition: **Pipeline script from SCM**
3. SCM: Git, Repo: 이 저장소
4. Script Path: `playbook/sandbox/userNN/Jenkinsfile` (NN 은 본인 슬롯)
5. Save → Build with Parameters (`loc` / `target_type` / `inventory_json` 입력)

## 어디를 수정해보면 좋을지

연습 아이디어 (난이도 낮은 순):

1. **`main.yml` 의 `vars:` 블록** — `practice_message` 를 본인 이름·메시지로 변경
2. **`main.yml` 의 task** — `ansible.builtin.copy` → `ansible.builtin.lineinfile` 로 바꿔서 한 줄씩 append 되게
3. **`pre.yml` 의 assert** — RHEL 8 도 허용하도록 조건 완화
4. **`post.yml` 의 slurp** — `slurp` 대신 `ansible.builtin.command: cat ...` + `register` 로 변경
5. **`Jenkinsfile`** — `Pre-check` 와 `Main` 사이에 stage 하나 추가 (예: `Lint` 로 `ansible-playbook --syntax-check`)
6. **모듈 교체** — `copy` 를 `template` 으로 바꾸고 `templates/practice.j2` 만들기
7. **handler 추가** — `main.yml` 에서 파일이 바뀌었을 때만 `notify` 로 debug 메시지 출력

## 슬롯 사이의 차이

내용은 모두 동일. 단지 Jenkinsfile 안에 자기 슬롯 경로가 박혀 있을 뿐:

```
playbook : "${WORKSPACE}/playbook/sandbox/userNN/{pre,main,post}.yml"
```

비교용으로 `git diff sandbox/user01/ sandbox/user02/` 떠보면, 슬롯 간 차이가 path 문자열 3줄뿐인 것을 확인할 수 있다.

## 주의

- `vault/linux.yml` 자격증명이 이미 구성돼 있어야 함 (저장소 [`README.md`](../../README.md) 참고)
- `inventory_json` 에는 RHEL 9 호스트만 포함시킬 것
- 이 디렉토리는 **연습용**. 운영 작업으로 쓰지 말 것. 운영 작업을 만들려면 [`playbook/tasks/`](../tasks/) 안에 새 디렉토리를 만드는 게 맞다.
