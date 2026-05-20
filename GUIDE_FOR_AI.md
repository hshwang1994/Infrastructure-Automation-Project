# GUIDE FOR AI

AI 가 이 저장소 컨벤션대로 Jenkinsfile / Playbook 을 만들거나 고칠 때 참고하는 입구 파일.

## 읽을 순서

1. `docs/jenkinsfile-guide.md` — Jenkinsfile 규칙
2. `docs/playbook-guide.md` — Playbook 규칙
3. `docs/ansible-cfg-guide.md` — ansible.cfg 표준 (Agent 측 설정)
4. `playbook/{linux-ntp,windows-service,esxi-uptime,redfish-bmc-info}/` — 작동하는 예시 (Jenkinsfile + site.yml)
5. `inventory/my_inventory.sh` — 인벤토리 라우팅 동작 (docstring 에 입출력 예시)
6. `credentials/README.md`, `vault/README.md` — 자격증명 흐름

## 새 작업 만들 때

1. `playbook/` 아래 새 디렉토리 생성: `playbook/{작업명}/`
2. 같은 target_type 의 기존 예시를 복사해서 시작
3. `Jenkinsfile` 의 `playbook:` 경로를 새 작업 경로로 수정
4. `site.yml` 의 tasks 만 새 작업 내용으로 교체

target_type 별 기본값은 `docs/playbook-guide.md` 의 표 참고.

## 자격증명

- 평문 원본: `credentials/{target_type}.yml`
- 암호화: `./scripts/encrypt-vault.sh` 실행 → `vault/{target_type}.yml` 생성
- Jenkins Credential 1개만 등록: Secret Text, ID `ansible-vault-password`
- Jenkinsfile 은 `vaultCredentialsId: 'ansible-vault-password'` 만 추가
- Playbook 은 `vars_files: vault/{target_type}.yml` 로 로딩

## 프롬프트 예시

```
이 저장소(Infrastructure-Automation-Project) 의 컨벤션을 따라
playbook/{작업명}/ 에 Jenkinsfile 과 site.yml 을 만들어줘.
{작업 설명}. 대상은 {target_type} 야.
```
