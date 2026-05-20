# credentials/ — 평문 자격증명 원본

이 디렉토리는 **ansible-vault 로 암호화되기 전의 평문 원본** 을 보관합니다.

## 디렉토리 역할

- 사람이 직접 편집하는 평문 YAML
- `scripts/encrypt-vault.sh` 가 이 파일들을 ansible-vault 로 암호화해서 `../vault/` 에 출력
- 실행 중 Ansible 이 읽는 파일은 `vault/*.yml` 이지 이 디렉토리가 아님

## 파일 목록

| 파일 | target_type | 출력 (암호화) |
|------|------------|-------------|
| `linux.yml` | linux | `../vault/linux.yml` |
| `windows.yml` | windows | `../vault/windows.yml` |
| `esxi.yml` | esxi | `../vault/esxi.yml` |
| `redfish.yml` | redfish | `../vault/redfish.yml` |

각 파일은 `ansible_user` / `ansible_password` (linux 는 추가로 `ansible_become_password`) 만 담는다. 비-시크릿 옵션(예: WinRM `ansible_winrm_transport`) 은 vault 가 아니라 playbook `vars` 에 둔다.

## 워크플로우

```
1. credentials/linux.yml 값 편집 (사람)
            ↓
2. scripts/encrypt-vault.sh 실행 (vault 비밀번호 입력)
            ↓
3. vault/linux.yml 생성/갱신 (ansible-vault 암호화)
            ↓
4. git commit (credentials/ 과 vault/ 둘 다)
            ↓
5. Jenkins 빌드 시 Jenkins Credential 'ansible-vault-password' 로 복호화
            ↓
6. playbook 이 ansible_user / ansible_password 변수 사용
```

## Jenkins 측 설정 (1회)

Manage Jenkins → Credentials → Global → Add Credentials:

| 항목 | 값 |
|------|-----|
| Kind | Secret text |
| Secret | 위 워크플로우 2번에서 입력한 vault 비밀번호 |
| ID | `ansible-vault-password` |

> **이 ID 가 Jenkinsfile 의 `vaultCredentialsId` 와 정확히 일치해야 한다.**

## 운영 이행 시 주의

- 운영 자격증명을 평문으로 commit 하고 싶지 않으면 `credentials/*.yml` 을 `.gitignore` 에 추가하고 `vault/*.yml` 만 commit 한다.
- 그러면 자격증명을 아는 사람만 로컬에서 `scripts/decrypt-vault.sh` 로 복호화 가능.
- 현재 사내 테스트 단계라 두 디렉토리 모두 commit 유지.
