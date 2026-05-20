# Automation Standards Guide

포털 → Jenkins → Ansible 자동화 작업의 컨벤션과 작동하는 예시를 모은 가이드 저장소.
실제 운영 Playbook 은 별도 작업 저장소에 둔다.

## 구조

```
.
├── docs/
│   ├── jenkinsfile-guide.md       Jenkinsfile 규칙
│   ├── playbook-guide.md          Playbook 규칙
│   └── ansible-cfg-guide.md       Agent 측 ansible.cfg 표준
├── playbook/                       작동하는 예시 (Jenkinsfile + site.yml 쌍)
│   ├── linux/                      linux target_type 예시들 (ntp, pkg-update, disk-check, roles, block-rescue, tags)
│   └── windows/                    windows target_type 예시들 (service, powershell)
├── inventory/
│   └── my_inventory.sh             동적 인벤토리 (포털 JSON → Ansible inventory)
├── credentials/                    평문 자격증명 원본 (사람이 편집)
├── vault/                          ansible-vault 암호화 자격증명 (런타임 사용)
├── scripts/
│   ├── encrypt-vault.sh            credentials/ → vault/
│   └── decrypt-vault.sh            vault/ → credentials/
└── GUIDE_FOR_AI.md                 AI 가 읽을 입구 파일
```

## 실행 흐름

```
포털 → loc, target_type, inventory_json 을 Jenkins job 에 전달
  → Jenkins job 이 ansiblePlaybook(vaultCredentialsId: ansible-vault-password) 실행
  → my_inventory.sh 가 inventory_json 을 Ansible inventory 로 변환
  → playbook 이 vars_files 로 vault/{target_type}.yml 로딩 (런타임 자동 복호화)
  → 작업 실행
```

## 새 작업 만들기

`playbook/{작업명}/` 에 `Jenkinsfile` + `site.yml` 추가. 같은 target_type 의 기존 예시를 복사해서 시작한다.

## 자격증명 초기 설정 (1회)

```
# 평문 값 확인/수정
vi credentials/linux.yml

# vault 암호화 (vault 비밀번호 입력)
./scripts/encrypt-vault.sh

git add vault/ && git commit -m "vault: encrypt" && git push
```

Jenkins UI → Manage Jenkins → Credentials → Global → Add:
- Kind: Secret text
- ID: `ansible-vault-password`
- Secret: 위에서 입력한 vault 비밀번호
