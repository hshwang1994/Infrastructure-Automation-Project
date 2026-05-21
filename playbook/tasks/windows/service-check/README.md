# tasks/windows/service-check — Windows 서비스 상태 점검

`ansible.windows.win_service` 모듈로 Spooler 서비스의 현재 상태를 조회해서 출력. 다른 서비스로 바꾸려면 `name:` 값만 교체하면 된다.

## 보여주는 패턴

- **windows 전용 특화 모듈 사용** — `ansible.windows.win_service`
- **connection: winrm** + ntlm transport + 5985 포트 (HTTP) 기본 설정
- **register 로 모듈 출력 사용** — `svc.state`, `svc.start_mode` 등 구조화된 결과를 그대로 활용

## task 흐름 (site.yml)

1. `win_service: name: Spooler` → `svc` 변수에 상태 저장
2. 호스트별 `Spooler={{ svc.state }}` debug 출력

## 변경되는 것

없음. 순수 조회 작업 (서비스 start/stop 등을 하려면 `state: started` / `stopped` 추가).

## 언제 이 패턴을 쓰나

Windows 의 서비스·레지스트리·DSC 처럼 **특화 모듈로 다룰 수 있는 영역**. 모듈이 제공하는 구조화된 결과를 그대로 쓸 수 있어서, raw 출력 파싱이 필요 없음. 반대로 모듈이 없거나 부족한 영역은 [`tasks/windows/sysinfo/`](../sysinfo/) 처럼 `win_shell` 로 처리.
