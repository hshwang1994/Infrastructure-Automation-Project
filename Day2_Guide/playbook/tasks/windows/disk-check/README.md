# tasks/windows/disk-check — 디스크 사용량 점검 (PowerShell raw)

전용 모듈 대신 `ansible.windows.win_shell` 로 PowerShell / CIM 을 직접 돌려 디스크 여유공간과 대용량 파일을 조회한다. Linux `disk-check` (df / find) 의 Windows 대응. 순수 조회 작업이라 변경 없음.

## 보여주는 패턴

- **shell / command raw** — 모듈로 다루기 까다로운 영역을 `win_shell` 로 처리
- **connection: winrm** + ntlm transport + `http` scheme + 5985 포트 (HTTP)
- **gather_facts: false** — fact 수집 없이 필요한 명령만 실행
- **changed_when: false** — 조회 전용 task 는 항상 ok (변경 아님)

## task 흐름 (site.yml)

1. `Win32_LogicalDisk` (DriveType=3, 로컬 디스크) → 드라이브별 Total/Free/Used%
2. `C:\` 하위 100MB 초과 파일 상위 5개
3. 호스트별 debug 출력

## 변경되는 것

없음. 순수 조회.

## 언제 이 패턴을 쓰나

`win_service` / `win_regedit` 같은 특화 모듈로 안 되는 자유 조회. 반대로 서비스·레지스트리처럼 전용 모듈이 있으면 [`tasks/windows/service-healthcheck/`](../service-healthcheck/) 처럼 특화 모듈을 쓴다.
