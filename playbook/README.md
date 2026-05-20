# playbook/ — 작성 예시

각 디렉토리는 하나의 작업. `Jenkinsfile` + `site.yml` 한 쌍이 기본, 다단계인 경우 stage 별로 분리된 playbook (`pre.yml` / `update.yml` 등) 을 두기도 함. 새 작업은 가장 비슷한 예시를 복사해서 시작.

## 작업 목록과 시연 패턴

| 디렉토리 | target_type | 시연하는 패턴 |
|---------|------------|---------------|
| `linux-ntp/` | linux | 빌트인 모듈 혼합 (systemd + command), 단일 stage |
| `linux-pkg-update/` | linux | 빌트인 (dnf/apt/stat/assert), **3단계** (Pre / Update / Post) |
| `linux-disk-check/` | linux | command/shell **만** 사용 (특화 모듈 없음) |
| `linux-roles/` | linux | **Role 구조** (`roles/{chrony,motd}/{tasks,handlers,defaults,templates}`) |
| `linux-block-rescue/` | linux | **block / rescue / always** 에러 처리 (sshd 안전 재시작) |
| `linux-tags/` | linux | **tags 분리** + Jenkinsfile 3 stage 가 같은 playbook 을 `tags` 별 호출 |
| `windows-service/` | windows | ansible.windows.win_service (특화 모듈) |
| `windows-powershell/` | windows | ansible.windows.win_shell **만** (raw PowerShell) |
| `esxi-uptime/` | esxi | command 만 |
| `redfish-bmc-info/` | redfish | ansible.builtin.uri |
| `redfish-fw-update/` | redfish | **다중 playbook + 다단계 + Jenkins `input` 수동 승인** (Pre / Backup / [APPROVE] / Upgrade / Verify) |

## 패턴 선택 기준

| 상황 | 추천 패턴 | 참고 예시 |
|------|----------|----------|
| 작업이 짧고 단순 | 단일 stage + 단일 playbook | `linux-ntp`, `windows-service` |
| 안전한 단계적 진행 (사전점검 / 본작업 / 사후검증) | Jenkinsfile 다단계 + playbook 분리 | `linux-pkg-update` |
| 위험 작업, 사람 결정 필요 | 다단계 + `input` 승인 게이트 | `redfish-fw-update` |
| 여러 곳에서 재사용될 묶음 단위 | Role | `linux-roles` |
| 실패 시 자동 롤백/복구 필요 | block / rescue / always | `linux-block-rescue` |
| 같은 playbook 을 부분 실행 (설치만, 검증만 등) | tags + Jenkinsfile 다단계 | `linux-tags` |
| 특화 모듈이 다루기 까다로운 환경 | shell/command/win_shell raw 호출 | `linux-disk-check`, `windows-powershell` |

규칙은 `docs/jenkinsfile-guide.md`, `docs/playbook-guide.md` 참고.
