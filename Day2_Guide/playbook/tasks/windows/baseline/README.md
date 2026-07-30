# tasks/windows/baseline — Baseline 구성 적용 (w32time + legalnotice)

신규 또는 재구성 Windows 호스트에 **공통 baseline** 을 설정. 시간 동기 (w32time) 와 로그온 법적 고지 배너 (legalnotice) 두 가지를 role 로 묶어 일괄 적용한다. Linux `baseline` (chrony + motd) 의 Windows 대응.

## 보여주는 패턴

- **Role 디렉토리 구조** — `roles/{w32time, legalnotice}/{tasks,handlers,defaults}` 표준 레이아웃
- **site.yml 은 얇음** — `roles: [w32time, legalnotice]` 만 선언, 실제 task 는 각 role 안에
- **defaults + 핸들러** — NTP 피어 변경 시 handler 로 `w32time` 서비스 재시작
- **windows 특화 처리** — 전용 NTP 모듈이 없어 `win_command` 로 `w32tm /config`, 배너는 `win_regedit` 레지스트리

## 디렉토리

```
baseline/
├── Jenkinsfile
├── site.yml                            roles 리스트만
└── roles/
    ├── w32time/{tasks,handlers,defaults}/main.yml
    └── legalnotice/{tasks,defaults}/main.yml
```

## 변경되는 것

- `w32time` 서비스 자동 시작 + NTP 피어 목록 구성 (`w32tm /config`)
- 로그온 화면에 법적 고지 배너 표시 (레지스트리 `legalnoticecaption` / `legalnoticetext`)

## 같은 패턴 학습용 데모

[`patterns/roles/`](../../../patterns/roles/) — Role 구조 최소 예시 (실제 작업 없이 구조만).
