# vault/ — ansible-vault 로 암호화된 자격증명

이 디렉토리의 파일들은 `credentials/*.yml` 평문을 `ansible-vault encrypt` 로 암호화한 결과물입니다.

## 생성 방법

```bash
./scripts/encrypt-vault.sh
```

자세한 워크플로우는 [`../credentials/README.md`](../credentials/README.md) 참고.

## 런타임 사용

Ansible 이 실행 중 자동으로 복호화한다. 사람이 직접 열어볼 일은 없음 (필요 시 `./scripts/decrypt-vault.sh`).

플러그인 측 결합:
- Jenkins Credential `ansible-vault-password` (Secret Text) 에 vault 비밀번호 등록
- Jenkinsfile 에서 `ansiblePlaybook(vaultCredentialsId: 'ansible-vault-password', ...)`

Playbook 측 결합:
```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/{target_type}.yml"
```

decrypted 된 결과로 `ansible_user`, `ansible_password` (linux 는 `ansible_become_password` 추가) 가 변수로 노출됨.

## 파일이 비어 있는 경우

처음 clone 한 직후나 신규 설정 시:
1. `credentials/{type}.yml` 의 평문 값 확인/편집
2. `./scripts/encrypt-vault.sh` 실행 → 이 디렉토리에 파일 생성됨
3. `git add vault/ && git commit`
