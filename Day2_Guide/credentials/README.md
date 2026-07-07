# credentials/ — 평문 자격증명 원본

여기 있는 yml 파일들은 ansible-vault 로 암호화되기 전의 **평문 원본**이다. 사람이 직접 편집하는 자리.

실제로 ansible 이 실행 중 읽는 건 `vault/*.yml` 쪽이고, 이 디렉토리는 그 원본일 뿐.

## 파일 목록

| 평문 (이 디렉토리) | 암호화 (vault/)         | target_type |
| :----------------- | :---------------------- | :---------- |
| `linux.yml`        | `../vault/linux.yml`    | linux       |
| `windows.yml`      | `../vault/windows.yml`  | windows     |

`linux.yml` 은 `ansible_user`, `ansible_password`, sudo 용 `ansible_become_password`, SSH client 옵션 `ansible_ssh_common_args` 를 담는다. 비밀번호가 아닌 설정도 vault 와 같이 들고 다니는 게 운영상 편해서 같이 묶었다 (자세한 설명은 파일 안 주석).

`windows.yml` 은 `ansible_user` / `ansible_password` 만 담는다. WinRM 의 transport / scheme / port 같은 비밀 아닌 연결 설정은 각 windows playbook 의 `vars` 블록에 둔다.

## 전체 흐름

```
1. credentials/linux.yml 값 편집 (사람이 손으로)
            ↓
2. ./scripts/encrypt-vault.sh 실행 → vault 비밀번호 입력
            ↓
3. vault/linux.yml 생성/갱신 (ansible-vault 암호화 결과로 덮어쓰기)
            ↓
4. git add credentials/ vault/  → commit + push
            ↓
5. Jenkins 빌드 시: vaultCredentialsId 로 Jenkins 가 들고있던 vault 비밀번호 전달
            ↓
6. ansible-playbook 이 vault/linux.yml 을 자동 복호화 →
   playbook 에서 ansible_user / ansible_password 변수로 사용 가능
```

## Jenkins 측 한 번 셋업 — Secret text 1개

Manage Jenkins → Credentials → System → Global → Add Credentials

| 항목   | 값                                            |
| :----- | :-------------------------------------------- |
| Kind   | Secret text                                   |
| ID     | `ansible-vault-password`                      |
| Secret | 위 흐름의 2번에서 입력한 vault 비밀번호       |

이 ID 가 Jenkinsfile 의 `vaultCredentialsId: 'ansible-vault-password'` 와 정확히 일치해야 한다.

## 운영 환경으로 옮길 때

- 운영 자격증명을 평문으로 commit 하기 싫으면 `credentials/*.yml` 을 `.gitignore` 에 추가하고 `vault/*.yml` 만 commit. 그러면 vault 비밀번호를 아는 사람만 로컬에서 `./scripts/decrypt-vault.sh` 로 평문을 다시 받아볼 수 있다.
- 지금은 사내 테스트 단계라 두 디렉토리 다 commit 유지.
