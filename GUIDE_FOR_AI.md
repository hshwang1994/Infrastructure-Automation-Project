# GUIDE FOR AI

AI 한테 이 저장소의 컨벤션을 따라 Jenkinsfile / Playbook 을 만들거나 고치게 시킬 때, 프롬프트에 같이 넣어주는 입구 파일.

## 읽는 순서

1. `docs/jenkinsfile-guide.md` — Jenkinsfile 규칙과 그 이유
2. `docs/playbook-guide.md` — Playbook 규칙과 hostvars 사용법
3. `docs/ansible-cfg-guide.md` — Agent 한 번 셋업 (ansible.cfg + sshpass + inventory 배치)
4. `playbook/linux/` 와 `playbook/windows/` 안의 작업 디렉토리들 — 실제 동작하는 Jenkinsfile + site.yml 예시
5. `inventory/my_inventory.sh` 상단 docstring — 포털 JSON → ansible inventory 변환 동작
6. `credentials/README.md`, `vault/README.md` — 자격증명이 평문 → 암호화 → 복호화 거치는 흐름

## 새 작업 만들기

1. `playbook/{linux|windows}/{작업명}/` 디렉토리 생성. 예: `playbook/linux/ntp-strict/`
2. 같은 target_type 의 기존 예시 디렉토리를 통째로 복사
3. 새 디렉토리의 `Jenkinsfile` 안 `playbook:` 경로를 새 디렉토리에 맞게 수정
4. 새 디렉토리의 `site.yml` (또는 다단계면 `pre.yml` / `update.yml` / `post.yml`) 의 `tasks` 만 새 작업 내용으로 바꿈

target_type 별 connection / gather_facts / become 기본값은 `docs/playbook-guide.md` 의 표.

## 자격증명 (한 번 셋업 후 신경 안 써도 됨)

- 평문 원본: `credentials/{target_type}.yml`
- 암호화 결과: `vault/{target_type}.yml` (`./scripts/encrypt-vault.sh` 로 생성)
- Jenkins 에 등록해야 할 것: Secret text 1개, ID `ansible-vault-password`, 값은 vault 비밀번호
- Jenkinsfile: `vaultCredentialsId: 'ansible-vault-password'` 한 줄
- Playbook: `vars_files: - "{{ lookup('env','REPO_ROOT') }}/vault/{target_type}.yml"`

새 작업은 위 자격증명 구조를 그대로 따른다. playbook 안에 비밀번호 평문이 절대 들어가면 안 됨.

## AI 한테 던지는 프롬프트 예시

```
이 저장소(Infrastructure-Automation-Project)의 컨벤션을 따라
playbook/linux/{작업명}/ 에 Jenkinsfile 과 site.yml 을 만들어줘.

{작업 내용 설명}

대상 target_type: linux
필요한 기능: {원하는 task 들}
```
