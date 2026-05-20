# playbook/ — 작성 예시

`linux/` 와 `windows/` 로 묶음. 각 작업 디렉토리는 `Jenkinsfile` 한 개 + playbook 파일 (단일 stage 면 `site.yml`, 다단계면 `pre.yml` / `update.yml` / `post.yml` 같은 식) 한 세트.

새 작업은 가장 비슷한 기존 디렉토리를 통째로 복사해서 시작한다.

## 작업 목록

| 디렉토리 | 보여주는 패턴 |
|---------|---------------|
| `linux/ntp/` | 빌트인 모듈 (systemd, command) 섞어 쓰기, 단일 stage |
| `linux/pkg-update/` | 빌트인 모듈 (dnf/apt/stat/assert/service_facts), Jenkinsfile **3 stage** (Pre-check → Update → Post-verify) |
| `linux/disk-check/` | 특화 모듈 없이 `command` / `shell` 만 써서 결과를 직접 가공 |
| `linux/roles/` | **Role 구조** — `roles/{chrony, motd}/{tasks,handlers,defaults,templates}` 표준 디렉토리 |
| `linux/block-rescue/` | **block / rescue / always** — sshd 안전 재시작 + 실패 시 백업으로 자동 롤백 |
| `linux/tags/` | **tags** 로 같은 site.yml 을 Install / Configure / Verify 세 stage 가 각각 부분 실행 |
| `windows/service/` | `ansible.windows.win_service` 같은 windows 전용 특화 모듈 사용 |
| `windows/powershell/` | `ansible.windows.win_shell` 만 사용해서 PowerShell 명령으로 모든 일 처리 |

## 어떤 패턴을 골라야 하나

| 상황 | 추천 패턴 | 참고 예시 |
|------|----------|----------|
| 작업이 짧고 단순 | 단일 stage + 단일 playbook | `linux/ntp`, `windows/service` |
| 안전한 단계적 진행 (사전점검 → 본작업 → 사후검증) | Jenkinsfile 다단계 + playbook 분리 | `linux/pkg-update` |
| 여러 작업에서 재사용될 묶음 단위 | Role | `linux/roles` |
| 실패 시 자동 롤백 / 복구 필요 | block / rescue / always | `linux/block-rescue` |
| 한 playbook 을 단계별로 부분 실행하고 싶을 때 | tags + Jenkinsfile 다단계 | `linux/tags` |
| 특화 모듈로 다루기 까다로운 환경 | shell / win_shell raw | `linux/disk-check`, `windows/powershell` |

규칙은 `docs/jenkinsfile-guide.md`, `docs/playbook-guide.md` 참고.
