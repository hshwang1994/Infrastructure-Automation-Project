# playbook/ — 작성 예시

`linux/` 와 `windows/` 두 디렉토리로 묶음. 각 작업 디렉토리는 `Jenkinsfile` + `site.yml` (다단계 작업은 `pre.yml` / `update.yml` / `post.yml`) 한 세트. 새 작업은 가장 비슷한 예시를 복사해서 시작.

## 작업 목록

| 디렉토리 | 시연하는 패턴 |
|---------|---------------|
| `linux/ntp/` | 빌트인 모듈 혼합 (systemd, command), 1 stage |
| `linux/pkg-update/` | 빌트인 (dnf, apt, stat, assert, service_facts), **3 stage** (Pre / Update / Post) |
| `linux/disk-check/` | command / shell **만** (특화 모듈 없음) |
| `linux/roles/` | **Role 구조** (`roles/{chrony, motd}/`) |
| `linux/block-rescue/` | **block / rescue / always** 에러 처리 (sshd 안전 재시작) |
| `linux/tags/` | **tags 로 부분 실행** + 3 stage 가 같은 site.yml 을 tag 별 호출 |
| `windows/service/` | ansible.windows.win_service (특화 모듈) |
| `windows/powershell/` | ansible.windows.win_shell **만** (raw PowerShell) |

## 상황별 패턴 선택

| 상황 | 추천 | 참고 |
|------|------|------|
| 작업이 짧고 단순 | 단일 stage | `linux/ntp`, `windows/service` |
| 사전점검 / 본작업 / 사후검증 | 다단계 + playbook 분리 | `linux/pkg-update` |
| 여러 곳에서 재사용될 묶음 | Role | `linux/roles` |
| 실패 시 자동 롤백 | block / rescue / always | `linux/block-rescue` |
| 같은 playbook 을 부분 실행 | tags + 다단계 | `linux/tags` |
| 특화 모듈이 까다로운 환경 | shell / win_shell raw | `linux/disk-check`, `windows/powershell` |

규칙은 `docs/jenkinsfile-guide.md`, `docs/playbook-guide.md` 참고.
