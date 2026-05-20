# Jenkinsfile 가이드

실제 예시는 `playbook/` 의 각 작업 디렉토리 Jenkinsfile 참고.

## 필수 구조

```groovy
pipeline {
    agent { label "${params.loc} && ${params.target_type}" }

    parameters {
        string(name: 'loc',         defaultValue: '', description: 'Agent 위치 (ich | chj | yi)')
        string(name: 'target_type', defaultValue: '', description: '대상 종류 (linux | windows | esxi | redfish)')
        text(  name: 'inventory_json', defaultValue: '[]', description: '타겟 호스트 JSON 배열')
    }

    environment {
        INVENTORY_JSON = "${params.inventory_json}"
        TARGET_TYPE    = "${params.target_type}"
        REPO_ROOT      = "${WORKSPACE}"
    }

    stages {
        stage('Run Ansible') {
            steps {
                ansiblePlaybook(
                    installation      : 'ansible',
                    playbook          : "${WORKSPACE}/playbook/{작업}/site.yml",
                    vaultCredentialsId: 'ansible-vault-password',
                    colorized         : true
                )
            }
        }
    }
}
```

## 규칙

- 파라미터 3개 (`loc`, `target_type`, `inventory_json`) 이름과 타입 고정.
- `inventory_json` 의 `defaultValue` 는 `'[]'` 만 둔다. 필드 스키마는 포털이 관리.
- `agent` 라벨은 `loc && target_type` AND 조건.
- `environment` 3개 (`INVENTORY_JSON`, `TARGET_TYPE`, `REPO_ROOT`) 고정.
- `ansiblePlaybook` 에서 `inventory` 파라미터 생략 (Agent 의 `/etc/ansible/ansible.cfg` 가 처리, `ansible-cfg-guide.md` 참고).
- 자격증명은 `vaultCredentialsId: 'ansible-vault-password'` 하나로 처리. `withCredentials` 나 `extraVars` 로 사용자/비밀번호를 직접 다루지 않는다.

## Jenkins Credentials 등록 (1회)

Manage Jenkins → Credentials → Global → Add

- Kind: Secret text
- ID: `ansible-vault-password`
- Secret: vault 비밀번호 (`scripts/encrypt-vault.sh` 실행 시 입력한 값)
