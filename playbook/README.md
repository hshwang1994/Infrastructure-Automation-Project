# playbook/ — 작성 예시

세 갈래로 나뉜다.

| 디렉토리                  | 내용                                                                                                       |
| :------------------------ | :--------------------------------------------------------------------------------------------------------- |
| [`tasks/`](tasks/)        | 실제 운영 작업 예시 (Jenkins 에서 그대로 호출). `linux/` 와 `windows/` 로 묶음                             |
| [`patterns/`](patterns/)  | Ansible 문법·구조 데모 (roles 디렉토리 / block-rescue / tags). 학습용                                      |
| [`sandbox/`](sandbox/)    | 연습용 슬롯 (`user01` ~ `user10` 10개, 모두 동일 RHEL 9 기준 3 stage 템플릿). 본인 슬롯의 yml 을 수정하며 학습 |

새 작업을 만들 때는 항상 `tasks/` 안에서 가장 비슷한 디렉토리를 복사해서 시작한다. `patterns/` 는 "이 문법은 어떻게 쓰는 거였지?" 를 빠르게 보고 싶을 때, `sandbox/` 는 처음 와서 Ansible / Jenkins 감각 익힐 때 보는 자리.

## tasks/ 작업 목록

각 디렉토리는 `Jenkinsfile` + playbook 파일 (단일 stage 면 `site.yml`, 다단계면 `pre.yml` / `update.yml` / `post.yml`) + `README.md` 한 세트.

### linux/

| 디렉토리                                                            | 작업                       | 보여주는 패턴                                                       |
| :------------------------------------------------------------------ | :------------------------- | :------------------------------------------------------------------ |
| [`tasks/linux/ntp/`](tasks/linux/ntp/)                              | NTP 동기 점검              | 빌트인 모듈 혼합, 단일 stage                                        |
| [`tasks/linux/pkg-update/`](tasks/linux/pkg-update/)                | dnf / apt 보안 패치        | Jenkinsfile 3 stage (Pre / Update / Post) + playbook 분리           |
| [`tasks/linux/disk-check/`](tasks/linux/disk-check/)                | df / find 디스크 점검      | shell·command raw                                                   |
| [`tasks/linux/baseline/`](tasks/linux/baseline/)                    | chrony + motd baseline     | **Role 구조** (`roles/{name}/{tasks,handlers,defaults,templates}`)  |
| [`tasks/linux/sshd-safe-reload/`](tasks/linux/sshd-safe-reload/)    | sshd 재시작 + 실패 시 롤백 | **block / rescue / always**                                         |
| [`tasks/linux/nginx-healthcheck/`](tasks/linux/nginx-healthcheck/)  | nginx + `/healthz` 배포    | **tags** 로 install / configure / verify 분리 + Jenkinsfile 다단계  |

### windows/

| 디렉토리                                                        | 작업                            | 보여주는 패턴                          |
| :-------------------------------------------------------------- | :------------------------------ | :------------------------------------- |
| [`tasks/windows/service-check/`](tasks/windows/service-check/)  | Spooler 서비스 상태 조회        | windows 특화 모듈 (`win_service`)      |
| [`tasks/windows/sysinfo/`](tasks/windows/sysinfo/)              | OS / 디스크 / 프로세스 정보 수집| `win_shell` raw (PowerShell 만 사용)   |

## patterns/ 데모 목록

| 디렉토리                                       | 보여주는 문법              | tasks/ 의 같은 패턴 사용 예                                      |
| :--------------------------------------------- | :------------------------- | :--------------------------------------------------------------- |
| [`patterns/roles/`](patterns/roles/)           | Role 디렉토리 구조         | [`tasks/linux/baseline/`](tasks/linux/baseline/)                 |
| [`patterns/block-rescue/`](patterns/block-rescue/) | block / rescue / always | [`tasks/linux/sshd-safe-reload/`](tasks/linux/sshd-safe-reload/) |
| [`patterns/tags/`](patterns/tags/)             | tags 로 부분 실행          | [`tasks/linux/nginx-healthcheck/`](tasks/linux/nginx-healthcheck/) |

## 어떤 작업 디렉토리를 골라야 하나

| 상황                                | 추천                                  | 참고 예시                                                       |
| :---------------------------------- | :------------------------------------ | :-------------------------------------------------------------- |
| 짧고 단순                           | 단일 stage + 단일 playbook            | `tasks/linux/ntp/`, `tasks/windows/service-check/`              |
| 사전점검 → 본작업 → 사후검증        | Jenkinsfile 다단계 + playbook 분리    | `tasks/linux/pkg-update/`                                       |
| 여러 작업에서 재사용될 묶음         | Role                                  | `tasks/linux/baseline/`                                         |
| 실패 시 자동 롤백                   | block / rescue / always               | `tasks/linux/sshd-safe-reload/`                                 |
| 같은 playbook 을 stage 별 부분 실행 | tags                                  | `tasks/linux/nginx-healthcheck/`                                |
| 모듈로 다루기 까다로움              | shell / win_shell raw                 | `tasks/linux/disk-check/`, `tasks/windows/sysinfo/`             |

규칙은 [`docs/jenkinsfile-guide.md`](../docs/jenkinsfile-guide.md), [`docs/playbook-guide.md`](../docs/playbook-guide.md) 참고.
