# vault/ — ansible 이 실행 중 읽는 자격증명 파일

## 두 가지 상태

이 디렉토리의 `*.yml` 은 **암호화 전** 과 **암호화 후** 두 상태가 가능하다.

| 상태                            | 파일 모양                                                          | 비고                                                              |
| :------------------------------ | :----------------------------------------------------------------- | :---------------------------------------------------------------- |
| **암호화 전** (현재 commit 상태) | `credentials/{type}.yml` 과 동일한 평문 YAML                       | 자리 잡기용 placeholder. 운영에선 commit 하지 말 것               |
| **암호화 후** (운영 상태)        | `$ANSIBLE_VAULT;1.1;AES256...` 로 시작하는 이진 비슷한 텍스트       | ansible-playbook 이 vault 비밀번호로 자동 복호화                  |

처음 clone 받으면 평문 placeholder 상태이고, `./scripts/encrypt-vault.sh` 를 한 번 돌리면 같은 파일들이 암호화 형식으로 덮어써진다.

## 처음 셋업

```bash
# 1. 평문 값 확인/수정
vi credentials/linux.yml

# 2. 암호화 — vault 비밀번호를 입력
./scripts/encrypt-vault.sh

# 3. 이제 vault/*.yml 이 $ANSIBLE_VAULT 헤더로 시작하는 암호문이 됨
head -1 vault/linux.yml
# $ANSIBLE_VAULT;1.1;AES256

# 4. commit
git add vault/ && git commit -m "vault: encrypt" && git push
```

이후 `credentials/` 의 값을 바꿀 때마다 2~4번 반복.

> `windows.yml` 도 같은 흐름이다. 인자 없이 `./scripts/encrypt-vault.sh` 를 돌리면 `linux` 와 `windows` 를 모두 암호화하고, `./scripts/encrypt-vault.sh windows` 로 windows 만 처리할 수도 있다. windows playbook 은 `connection: winrm` (5985 HTTP) 로 접속하며 `ansible_user` / `ansible_password` 를 이 vault 에서 읽는다.

## ansible 이 어떻게 쓰는가

Jenkinsfile:
```groovy
ansiblePlaybook(..., vaultCredentialsId: 'ansible-vault-password')
```

Playbook:
```yaml
vars_files:
  - "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"
```

→ ansible-playbook 이 위 Jenkins credential 의 값을 vault 비밀번호로 받아 자동 복호화 → playbook 안에서 `ansible_user`, `ansible_password` 가 변수로 잡힘.

## 디버그용으로 평문 보고 싶을 때

```bash
./scripts/decrypt-vault.sh    # vault/*.yml → credentials/*.yml 평문으로 복원
```
