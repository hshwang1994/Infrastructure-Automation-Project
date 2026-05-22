# tasks/linux/baseline — Baseline 구성 적용 (chrony + motd)

신규 또는 재구성 호스트에 **공통 baseline** 을 설정. 시간 동기 (chrony) 와 로그인 배너 (motd) 두 가지를 role 로 묶어 일괄 적용한다.

## 보여주는 패턴

- **Role 디렉토리 구조** — `roles/{chrony, motd}/{tasks,handlers,defaults,templates}` 표준 레이아웃
- **site.yml 은 얇음** — `roles: [chrony, motd]` 만 선언, 실제 task 는 각 role 안에
- **defaults + 핸들러** — chrony 설정 파일 변경 시 handler 로 `chronyd` 재시작

## 디렉토리

```
baseline/
├── Jenkinsfile
├── site.yml                            roles 리스트만
└── roles/
    ├── chrony/{tasks,handlers,defaults}/main.yml
    └── motd/{tasks,templates}/main.yml
```

## 변경되는 것

- chrony 패키지 설치 + `chronyd` 활성화
- `/etc/motd` 가 호스트별 banner 로 교체

## 같은 패턴 학습용 데모

[`patterns/roles/`](../../../patterns/roles/) — Role 구조 최소 예시 (chrony 같은 실제 작업 없이 구조만).
