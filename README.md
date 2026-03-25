# Infrastructure Automation Project

Jenkins + Ansible 기반의 인프라 자동화 프로젝트입니다.
포털에서 IP만 전달하면, Jenkins Pipeline이 Ansible Playbook을 실행하여 서버 구성 및 운영 작업을 자동으로 수행합니다.

## 프로젝트 구조

```
Infrastructure-Automation-Project/
  playbooks/
    day1/                  ← 서버 최초 구성 작업 (OS 초기 설정, 패키지 설치 등)
    day2/                  ← 운영 작업 (점검, 패치, 펌웨어 등)
  docs/
    jenkins-guide.md       ← Jenkinsfile 작성 가이드
    playbook-guide.md      ← Ansible Playbook 작성 가이드
  inventory/
    my_inventory.sh        ← 동적 인벤토리 스크립트
  vault/
    linux.yml              ← Linux 접속 계정
    windows.yml            ← Windows 접속 계정
    esxi.yml               ← ESXi 접속 계정
    redfish/               ← BMC 벤더별 접속 계정
  GUIDE_FOR_AI.md          ← AI 자동 생성 가이드
```

## 실행 흐름

```
포털 (HTTP POST)
  ├─ loc: 실행 위치 (Jenkins agent label)
  ├─ target_type: 대상 종류
  └─ inventory_json: [{"ip":"10.x.x.1", "hostname":"server-01"}]
         ↓
Jenkins Pipeline (Jenkinsfile)
  ├─ environment: REPO_ROOT, INVENTORY_JSON
  └─ stages: ansiblePlaybook() 호출
         ↓
Ansible Playbook (site.yml)
  ├─ vault 자동 로딩
  ├─ 동적 인벤토리 (my_inventory.sh)
  └─ 작업 수행 → 결과 출력
```

## Jenkins Pipeline 패턴 (4가지)

| 패턴 | 설명 | 예시 |
|------|------|------|
| Single-Stage Single-Playbook | 1 스테이지, 1 플레이북 | Ping 테스트 |
| Single-Stage Multi-Playbook | 1 스테이지, 여러 플레이북 순차 | 네트워크 + 리소스 점검 |
| Multi-Stage Single-Playbook | 여러 스테이지, 각 1 플레이북 | 서비스 → 디스크 → 판정 |
| Multi-Stage Multi-Playbook | 여러 스테이지, 각 여러 플레이북 | 호스트/스토리지 → 메모리/네트워크 → 요약 |

## 새 작업 추가

1. `playbooks/day1/` 또는 `playbooks/day2/` 하위에 `{작업명}/{OS타입}/` 디렉토리 생성
2. `Jenkinsfile` + `site.yml` 작성
3. [GUIDE_FOR_AI.md](GUIDE_FOR_AI.md) 및 [docs/jenkins-guide.md](docs/jenkins-guide.md) 참고

## 지원 대상

| 대상 | 프로토콜 | vault 파일 |
|------|---------|-----------|
| Linux | SSH (22) | `vault/linux.yml` |
| Windows | WinRM (5985/5986) | `vault/windows.yml` |
| ESXi | SSH (22) | `vault/esxi.yml` |
| Redfish (BMC) | HTTPS (443) | `vault/redfish/{vendor}.yml` |
