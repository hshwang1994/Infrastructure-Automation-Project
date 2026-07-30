# sandbox/ — 연습용 슬롯

`tasks/` 가 실제 운영 작업, `patterns/` 가 문법 데모라면, `sandbox/` 는 **사용자가 직접 들어와서 yml 을 하나씩 수정해보면서 익히는 연습장**.

## 슬롯 구조

`user01/` ~ `user10/` 까지 **10개 슬롯이 모두 동일한 내용**으로 들어 있다. 1인 1슬롯 점유하면 다른 사람과 충돌 없이 자유롭게 수정 가능.

각 슬롯 안 (`user01/` 기준):

```
user01/
├── Jenkinsfile      3 stage (Builtin / Shell / ExtraVars)
├── main.yml         /tmp/practice.txt 작성 (ansible.builtin.copy)
├── post.yml         같은 파일을 쉘 명령(test/cat)으로 검증 (ansible.builtin.shell)
├── extravars.yml    Jenkinsfile 의 params·env 를 ansible 변수로 받아 debug
└── README.md        슬롯 안내 (이 파일의 짧은 stub)
```

## 대상

**linux** 호스트 — Builtin / Shell stage. 환경 검증은 따로 안 하므로 (Pre-check stage 없음) `inventory_json` 의 호스트는 SSH/sudo 가 가능한 일반 linux 면 됨.

**ExtraVars stage** 는 `hosts: localhost` / `connection: local` 로 ansible 컨트롤러 (= Jenkins agent) 에서 실행하므로 SSH 불필요 (vault 자동 복호화는 다른 stage 와 동일하게 plugin 이 처리).

## 3 stage 구성

| stage      | playbook         | 모듈                       | 내용                                                                         |
| :--------- | :--------------- | :------------------------- | :--------------------------------------------------------------------------- |
| Builtin    | `main.yml`       | `ansible.builtin.copy`     | `/tmp/practice.txt` 에 메시지 + 타임스탬프 작성 (고수준 모듈)                |
| Shell      | `post.yml`       | `ansible.builtin.shell`    | 같은 파일을 `test -f` + `cat` 쉘 명령으로 존재·내용 확인                     |
| ExtraVars  | `extravars.yml`  | `ansible.builtin.debug`    | Jenkinsfile 의 `greeting` 파라미터를 `extraVars` 로 전달 → debug 출력        |

세 stage 모두 `/tmp/` 영역만 건드리거나 read-only 라 안전하게 멱등. 반복 실행 OK.

## 왜 3 stage 인가

각 stage 가 서로 다른 "ansible 사용 패턴" 을 하나씩 보여준다:

1. **Builtin (`main.yml`)** — 고수준 모듈의 멱등성·자동 권한 처리
2. **Shell (`post.yml`)** — shell 명령으로 같은 결과를 만들었을 때의 차이 (로그·에러·idempotency)
3. **ExtraVars (`extravars.yml`)** — `ansiblePlaybook(extraVars: [...])` 로 Jenkins 파라미터를 ansible 변수로 전달

`main.yml` ↔ `post.yml` 을 나란히 읽으면 모듈 vs shell 차이를, `extravars.yml` 은 Jenkins 파라미터를 ansible 안 변수로 받는 표준 패턴을 익힐 수 있다.

## 기본 파라미터

네 파라미터 전부 `defaultValue` 가 박혀 있어서 별다른 입력 없이 **Build with Parameters → Build** 한 번이면 끝.

| 파라미터          | 기본값                                                                          | 의미                                                  |
| :---------------- | :------------------------------------------------------------------------------ | :---------------------------------------------------- |
| `loc`             | `ich`                                                                           | Agent 위치 라벨                                       |
| `target_type`     | `linux`                                                                         | 대상 종류 (이 슬롯은 linux 고정)                      |
| `inventory_json`  | `[{"hostname":"linux-dev-01","service_ip":"10.100.64.169"}]`                    | 사내 linux 데모 호스트 1대 (2대 이상 예시는 Jenkinsfile 주석) |
| `greeting`        | `hello from jenkins`                                                            | ExtraVars stage 데모 — ansible 로 넘기는 파라미터 1개 |

다른 호스트로 돌리려면 `inventory_json` 만 바꾸면 된다.

## 사용 흐름

1. 본인 슬롯 하나 정함 (예: `user03`)
2. Jenkins Pipeline job 만들고 Script Path: `Day2_Guide/playbook/sandbox/user03/Jenkinsfile`
3. **Build with Parameters → Build** (기본값 그대로) — 한 번 성공 확인
4. yml 을 하나씩 수정해보면서 변화 관찰

## Jenkins 에 등록하기

1. Pipeline 타입 job 새로 만들기
2. Pipeline → Definition: **Pipeline script from SCM**
3. SCM: Git, Repo: 이 저장소
4. Script Path: `Day2_Guide/playbook/sandbox/userNN/Jenkinsfile` (NN 은 본인 슬롯)
5. Save → Build with Parameters → 기본값 그대로 Build

## 어디를 수정해보면 좋을지

연습 아이디어 (난이도 낮은 순):

1. **`main.yml` 의 `vars:` 블록** — `practice_message` 를 본인 이름·메시지로 변경
2. **`main.yml` 의 task** — `ansible.builtin.copy` → `ansible.builtin.lineinfile` 로 바꿔서 한 줄씩 append 되게
3. **`post.yml` 의 shell** — `cat` 대신 `tail -1` 로 마지막 줄만 가져오게
4. **`post.yml` 을 builtin 으로 다시 작성** — `ansible.builtin.stat` + `slurp` 로 같은 검증 구현해서 main/post 를 같은 모듈군으로 통일
5. **`Jenkinsfile`** — `Builtin` 앞에 stage 하나 추가 (예: `Lint` 로 `ansible-playbook --syntax-check`, 또는 `Pre-check` 로 환경 검증)
6. **handler 추가** — `main.yml` 에서 파일이 바뀌었을 때만 `notify` 로 debug 메시지 출력

## 슬롯 사이의 차이

내용은 모두 동일. 단지 Jenkinsfile 안에 자기 슬롯 경로가 박혀 있을 뿐:

```
playbook : "${WORKSPACE}/Day2_Guide/playbook/sandbox/userNN/{main,post}.yml"
```

비교용으로 `git diff sandbox/user01/ sandbox/user02/` 떠보면, 슬롯 간 차이가 path 문자열 2줄뿐인 것을 확인할 수 있다.

## 주의

- `vault/linux.yml` 자격증명이 이미 구성돼 있어야 함 (저장소 [`README.md`](../../README.md) 참고)
- 기본 `inventory_json` 의 `10.100.64.169` 가 살아있는 linux 호스트여야 정상 동작
- 이 디렉토리는 **연습용**. 운영 작업으로 쓰지 말 것. 운영 작업을 만들려면 [`playbook/tasks/`](../tasks/) 안에 새 디렉토리를 만드는 게 맞다.
