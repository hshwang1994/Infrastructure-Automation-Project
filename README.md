# Infrastructure Automation Project

Jenkins + Ansible 기반 인프라 자동화 프로젝트입니다.
포털에서 작업을 요청하면 Jenkins 가 Ansible Playbook 을 실행하여 서버를 관리합니다.

## 전체 흐름

```
포털 (HTTP POST)
  ├─ loc: "ich | chj | yi"           ← Agent 위치
  ├─ target_type: "linux | windows | esxi | redfish"
  └─ inventory_json: [{"bmc_ip": "...", "service_ip": "...", ...}]
         ↓
    Jenkins Job
    ├─ 파라미터 수신 (loc, target_type, inventory_json)
    ├─ 환경변수 설정 (INVENTORY_JSON, TARGET_TYPE, REPO_ROOT)
    └─ ansible-playbook 실행
         ↓
    Ansible
    ├─ inventory/my_inventory.sh → 동적 인벤토리 생성
    ├─ vault/*.yml → 인증정보 로딩
    └─ playbook 실행 → 결과 출력
```

## 프로젝트 구조

```
Infrastructure-Automation-Project/
├── docs/                          ← 개발자 가이드 (필독)
│   ├── jenkinsfile-guide.md       ← Jenkinsfile 작성 표준
│   └── playbook-guide.md          ← Playbook 작성 표준
├── playbooks/                     ← Jenkinsfile + Playbook
│   ├── day1/                      ← 서버 최초 구성 작업
│   └── day2/                      ← 운영 작업 (점검, 패치 등)
├── inventory/
│   └── my_inventory.sh            ← 동적 인벤토리 스크립트
├── vault/                         ← 접속 계정 정보
│   ├── linux.yml
│   ├── windows.yml
│   ├── esxi.yml
│   └── redfish/
│       ├── dell.yml
│       ├── hpe.yml
│       ├── lenovo.yml
│       └── supermicro.yml
└── GUIDE_FOR_AI.md                ← AI 자동 생성용 가이드
```

## 새 작업 추가 방법

1. `docs/jenkinsfile-guide.md` 를 읽고 Jenkinsfile 작성
2. `docs/playbook-guide.md` 를 읽고 Playbook 작성
3. `playbooks/day1/` 또는 `playbooks/day2/` 하위에 디렉토리 생성
4. Jenkins 에 Job 등록

```
playbooks/day2/{작업명}/{OS타입}/
  ├── Jenkinsfile
  └── site.yml
```

## 예시 Playbook 패턴 (day2)

| 패턴 | 설명 | 위치 |
|------|------|------|
| single-stage-single-playbook | 1스테이지, 1플레이북 | `day2/single-stage-single-playbook/linux/` |
| single-stage-multi-playbook | 1스테이지, N플레이북 | `day2/single-stage-multi-playbook/linux/` |
| multi-stage-single-playbook | N스테이지, 1플레이북 | `day2/multi-stage-single-playbook/linux/` |
| multi-stage-multi-playbook | N스테이지, N플레이북 | `day2/multi-stage-multi-playbook/linux/` |

## 핵심 설계 원칙

**인벤토리 스크립트 = 라우터**

- `TARGET_TYPE` 을 보고 `inventory_hostname` / `ansible_host` 를 결정
- 나머지 필드는 이름이 뭐든 값이 뭐든 그대로 `hostvars` 에 전달
- 필드의 의미 해석은 각 Playbook 의 책임

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | bmc_ip | bmc_ip |
| linux / windows / esxi | hostname | service_ip |
