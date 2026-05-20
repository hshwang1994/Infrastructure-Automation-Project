# vault/ — 자격증명 파일 (런타임 사용)

이 디렉토리의 `*.yml` 은 Ansible 이 런타임에 읽는 자격증명 파일입니다.

## 파일 상태 — 두 가지

| 상태 | 모양 | 비고 |
|------|------|------|
| **암호화 전 (현재)** | 평문 YAML — `credentials/{type}.yml` 와 동일한 내용 | placeholder, **commit 하지 말 것 권장** |
| **암호화 후 (운영용)** | `$ANSIBLE_VAULT;1.1;AES256...` 로 시작하는 ansible-vault 형식 | 정상 상태, commit 가능 |

## 처음 사용할 때 절차

1. `credentials/{type}.yml` 의 평문 값 확인/편집 (필요 시)
2. `./scripts/encrypt-vault.sh` 실행 → vault 비밀번호 입력
3. 이 디렉토리의 `*.yml` 이 ansible-vault 형식으로 **덮어써짐**
4. `git add vault/ && git commit -m "vault: encrypt"`

## 파일 내용 확인 (현재는 평문이므로 그대로 보임)

암호화 전:
```yaml
---
ansible_user:     infra
ansible_password: infra1234
```

암호화 후:
```
$ANSIBLE_VAULT;1.1;AES256
66386439653236336462626566653063336164663966303231363934653561363964363833313662
6431626536303530376336343832656537303632313433360a626438346336353331386135323734
...
```

## 런타임 결합

플러그인 측:
- Jenkins Credential `ansible-vault-password` (Secret Text) 에 vault 비밀번호 등록
- Jenkinsfile 에서 `ansiblePlaybook(vaultCredentialsId: 'ansible-vault-password', ...)`

Playbook 측:
```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/{target_type}.yml"
```

복호화 결과로 `ansible_user`, `ansible_password` (linux 는 `ansible_become_password` 추가) 가 변수로 노출됨.

## 디버그용 복호화

`./scripts/decrypt-vault.sh` 실행 → vault 비밀번호 입력 → `credentials/` 에 평문이 다시 채워짐.
