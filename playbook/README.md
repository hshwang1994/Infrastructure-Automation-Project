# playbook/ — 작성 예시

각 디렉토리는 `Jenkinsfile` + `site.yml` (또는 다단계인 경우 `pre.yml` / `update.yml` / `post.yml`) 한 세트. 새 작업 만들 때 가장 비슷한 예시를 복사해서 시작한다.

## 목록

| 디렉토리 | target_type | 모듈 사용 패턴 | Jenkinsfile 스테이지 |
|---------|------------|--------------|---------------------|
| `linux-ntp/` | linux | builtin (systemd, command) | 1 |
| `linux-pkg-update/` | linux | builtin (dnf, apt, stat, assert, service_facts) | **3** (Pre-check / Update / Post-verify) |
| `linux-disk-check/` | linux | shell / command 만 (특화 모듈 없음) | 1 |
| `windows-service/` | windows | ansible.windows.win_service (특화 모듈) | 1 |
| `windows-powershell/` | windows | ansible.windows.win_shell 만 (raw PowerShell) | 1 |
| `esxi-uptime/` | esxi | command 만 | 1 |
| `redfish-bmc-info/` | redfish | ansible.builtin.uri | 1 |

## 패턴별 참고

- **빌트인 특화 모듈 활용**: `linux-ntp`, `linux-pkg-update`, `windows-service` — idempotency, when 조건, register 활용
- **raw shell/powershell 만**: `linux-disk-check`, `windows-powershell` — 자체 명령 결과 가공
- **다단계 Jenkinsfile**: `linux-pkg-update` — pre-check → action → post-verify 흐름

규칙은 `docs/jenkinsfile-guide.md`, `docs/playbook-guide.md` 참고.
