# Automation Standards Guide

> Jenkins + Ansible 자동화 작업을 우리 환경(공통 인벤토리 스크립트 + 공용 Jenkins Agent + ansible-vault)에 맞춰 어떻게 작성해야 하는지 정리한 **표준 가이드 저장소**입니다.
> 실제 운영 Playbook 코드는 이 저장소에 두지 않습니다.

## 이 저장소의 역할

이 저장소는 **무엇을 작성할지가 아니라, 어떻게 작성할지**를 정의합니다.

- 새 Jenkins Job / Ansible Playbook 을 만들 때 따라야 할 **컨벤션**
- 우리 환경(`inventory/my_inventory.sh`, 공용 Agent, ansible-vault + Jenkins Credentials)에 **어떻게 연결**해야 하는지
- AI 가 컨벤션에 맞게 코드를 생성하도록 돕는 **컨텍스트 입력**

실제 운영 Playbook 은 별도의 작업 저장소에 위치합니다.

## 우리 환경 기본 구성

```
포털 (HTTP POST)
  ├─ loc: "ich | chj | yi"           ← Agent 위치
  ├─ target_type: "linux | windows | esxi | redfish"
  └─ inventory_json: [{"bmc_ip": "...", "service_ip": "...", ...}]
         ↓
    Jenkins Job (이 가이드 표준 준수)
    ├─ 파라미터 수신 (loc, target_type, inventory_json)
    ├─ 환경변수 설정 (INVENTORY_JSON, TARGET_TYPE, REPO_ROOT)
    └─ ansiblePlaybook(vaultCredentialsId: 'ansible-vault-password') 실행
         ↓
    Ansible
    ├─ inventory/my_inventory.sh → 동적 인벤토리 생성
    ├─ playbook 의 vars_files 가 vault/{type}.yml 로딩 시 자동 복호화
    │  → ansible_user / ansible_password 변수 노출
    └─ playbook 실행 → 결과 출력
```

## 저장소 구조

```
automation-standards-guide/
├── docs/                          ← 가이드 본문 (필독)
│   ├── ansible-cfg-guide.md       ← ansible.cfg 표준
│   ├── jenkinsfile-guide.md       ← Jenkinsfile 작성 표준 (Jenkins Credentials 포함)
│   └── playbook-guide.md          ← Playbook 작성 표준
├── inventory/
│   └── my_inventory.sh            ← 모든 작업이 공통으로 쓰는 동적 인벤토리 스크립트
├── credentials/                   ← 평문 자격증명 원본 (사람이 편집)
│   ├── README.md
│   ├── linux.yml / windows.yml / esxi.yml / redfish.yml
├── vault/                         ← ansible-vault 로 암호화된 결과 (런타임 사용)
│   ├── README.md
│   └── (encrypt-vault.sh 실행 후 생성됨)
├── scripts/
│   ├── encrypt-vault.sh           ← credentials/ → vault/ 일괄 암호화
│   └── decrypt-vault.sh           ← vault/ → credentials/ 일괄 복호화 (디버그용)
└── GUIDE_FOR_AI.md                ← AI 자동 생성용 컨텍스트
```

> 실제 인증은 **ansible-vault 로 암호화된 vault/{type}.yml 을 ansible-playbook 이 런타임에 복호화** 해서 수행합니다.
> Jenkins Credentials 에는 **vault 복호화 비밀번호 하나만** (Secret Text `ansible-vault-password`) 보관합니다.
> 사용 흐름은 `credentials/README.md` 참고.

## 새 작업 추가 시 따라야 할 흐름

1. `docs/jenkinsfile-guide.md` 를 읽고 Jenkinsfile 작성 규칙 확인
2. `docs/playbook-guide.md` 를 읽고 Playbook 작성 규칙 확인
3. `docs/ansible-cfg-guide.md` 를 읽고 ansible.cfg 표준 확인
4. 작업 저장소에 위 표준에 맞게 Jenkinsfile + Playbook 작성
5. Jenkins 에 Job 등록

## 설계 원칙

**인벤토리 스크립트 = 라우터**

- `TARGET_TYPE` 을 보고 `inventory_hostname` / `ansible_host` 결정
- 나머지 필드는 그대로 `hostvars` 에 전달
- 필드 해석은 각 Playbook 에서 처리

| target_type | inventory_hostname | ansible_host |
|------------|-------------------|-------------|
| redfish | bmc_ip | bmc_ip |
| linux / windows / esxi | hostname | service_ip |
