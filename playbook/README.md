# playbook/ — 작성 예시

각 디렉토리는 `Jenkinsfile` + `site.yml` 한 쌍. 새 작업 만들 때 이 구조를 복제해서 시작한다.

| 디렉토리 | target_type | 내용 |
|---------|------------|------|
| `linux-ntp/` | linux | chronyd 상태 확인 |
| `windows-service/` | windows | Spooler 서비스 상태 |
| `esxi-uptime/` | esxi | uptime 조회 |
| `redfish-bmc-info/` | redfish | BMC Systems 목록 조회 |

규칙은 `docs/jenkinsfile-guide.md`, `docs/playbook-guide.md` 참고.
