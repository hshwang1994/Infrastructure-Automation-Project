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

각 부분이 무슨 일을 하는지:

| 단계 | 누가 | 무엇을 |
|------|------|-------|
| 1 | 포털 | `loc`, `target_type`, `inventory_json` 세 파라미터로 Jenkins job 트리거 |
| 2 | Jenkinsfile | 위 값을 환경변수로 노출하고 `ansiblePlaybook(vaultCredentialsId: ...)` 호출 |
| 3 | `inventory/my_inventory.sh` | `INVENTORY_JSON` + `TARGET_TYPE` 을 읽어 ansible 인벤토리 JSON 으로 변환 |
| 4 | ansible-playbook | playbook 의 `vars_files` 로 `vault/{target_type}.yml` 을 읽으면서 Jenkins 가 넘긴 vault 비밀번호로 자동 복호화 |
| 5 | playbook | `ansible_user` / `ansible_password` 로 타겟 서버에 SSH/WinRM/HTTPS 접속 후 task 실행 |

## 새 작업 만들기

`playbook/{linux|windows}/{작업명}/` 디렉토리를 만들고 그 안에 `Jenkinsfile` + `site.yml` 을 둔다. 가장 비슷한 기존 예시 디렉토리를 통째로 복사해서 시작하면 된다.

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
