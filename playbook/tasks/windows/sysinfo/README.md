# tasks/windows/sysinfo — Windows 시스템 정보 수집

OS 버전, 디스크 사용량, CPU 사용 상위 5개 프로세스를 PowerShell 로 한 번에 모아서 호스트별로 출력.

## 보여주는 패턴

- **`ansible.windows.win_shell` 만 사용** — 특화 모듈 없이 PowerShell 명령으로 모든 일 처리
- **connection: winrm** + ntlm transport + 5985 포트
- **CIM (`Get-CimInstance`)** — WMI 보다 모던한 시스템 조회 API
- **`changed_when: false`** — 조회 명령이라 항상 OK 처리
- **`ConvertTo-Json -Compress`** — Ansible 쪽에서 구조 파싱하기 쉬운 형태로 출력 (필요하면 `from_json` 필터로 받아서 처리)

## task 흐름 (site.yml)

1. OS 정보 (`Win32_OperatingSystem` → caption / version / build / lastBootUpTime)
2. 디스크 사용량 (`Win32_LogicalDisk` 중 DriveType=3 의 Size/FreeSpace, GB 환산)
3. CPU 사용 상위 5 프로세스 (`Get-Process | Sort CPU -Desc | Select -First 5`)
4. 세 결과를 호스트별 단일 debug 메시지로 묶어 출력

## 변경되는 것

없음. 순수 조회 작업.

## 언제 이 패턴을 쓰나

Windows 특화 모듈로 다루기 까다로운 영역 (모듈이 없거나, 모듈 출력이 부족하거나, 여러 CIM 클래스를 조합해야 할 때). Linux 쪽 대응 예시는 [`tasks/linux/disk-check/`](../../linux/disk-check/) — 동일하게 raw 명령으로 출력 가공.
