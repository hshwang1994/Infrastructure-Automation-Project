# Jenkinsfile 가이드

실제 예시는 `playbook/tasks/linux/` 안의 각 작업 디렉토리 Jenkinsfile 참고.

## 필수 구조

```groovy
pipeline {
    agent { label "${params.loc} && ${params.target_type}" }

    parameters {
        string(name: 'loc',         defaultValue: '', description: 'Agent 위치 (ich | chj | yi)')
        string(name: 'target_type', defaultValue: 'linux', description: '대상 종류 (linux 고정)')
        text(  name: 'inventory_json', defaultValue: '[]', description: '타겟 호스트 JSON 배열')
    }

    environment {
        INVENTORY_JSON = "${params.inventory_json}"
        TARGET_TYPE    = "${params.target_type}"
        REPO_ROOT      = "${WORKSPACE}/Day2_Guide"
    }

    stages {
        stage('Run Ansible') {
            steps {
                ansiblePlaybook(
                    installation      : 'ansible',
                    playbook          : "${WORKSPACE}/Day2_Guide/playbook/{작업}/site.yml",
                    vaultCredentialsId: 'ansible-vault-password',
                    colorized         : true
                )
            }
        }
    }
}
```

## 각 부분이 왜 그렇게 쓰여 있는지

### parameters 3개의 이름은 고정

`loc`, `target_type`, `inventory_json` 은 포털이 빌드 트리거할 때 채워서 보내는 값이다. 포털 쪽 코드가 이 이름으로 보내고 있으니 Jenkinsfile 에서 이름을 바꾸면 안 된다.

`inventory_json` 의 `defaultValue` 는 빈 배열 `'[]'` 만 둔다. 실제 호스트 목록은 포털이 매번 다르게 보낸다 — 어떤 필드 (bmc_ip / mgmt_ip / os_image …) 가 올지는 작업마다 달라서, Jenkinsfile 에 미리 박아두면 작업 추가될 때마다 손대야 한다.

### agent 라벨이 두 라벨의 AND

```groovy
agent { label "${params.loc} && ${params.target_type}" }
```

`loc` 라벨 (예: `ich`) 과 `target_type` 라벨 (`linux`) 을 **둘 다** 가진 Agent 에서만 실행된다. 인천 사이트의 linux 처리 전용 agent, 청주 사이트의 linux 처리 전용 agent 같은 구분을 라벨 조합으로 표현하기 위해서.

### environment 3개

| 변수               | 사용처                                                                                                       |
| :----------------- | :----------------------------------------------------------------------------------------------------------- |
| `INVENTORY_JSON`   | `inventory/my_inventory.sh` 가 호스트 목록을 읽을 때                                                         |
| `TARGET_TYPE`      | `inventory/my_inventory.sh` 가 호스트명·접속 IP 매핑 결정할 때 (linux 면 hostname → inventory_hostname, service_ip → ansible_host) |
| `REPO_ROOT`        | playbook 안에서 `vault/`, `roles/` 같은 저장소 내 파일을 절대 경로로 참조할 때. Jenkins 가 빌드마다 워크스페이스 경로를 바꾸므로 상대 경로는 깨지기 쉬움. |

### inventory 파라미터 생략

`ansiblePlaybook()` 에 `inventory` 를 적지 않는다. Agent 의 `/etc/ansible/ansible.cfg` 에 인벤토리 경로가 이미 박혀 있어서 ansible 이 자동으로 쓴다. 셋업 절차는 `ansible-cfg-guide.md` 참고.

### 자격증명은 vaultCredentialsId 한 줄로

```groovy
vaultCredentialsId: 'ansible-vault-password'
```

`ansible-vault-password` 는 Jenkins UI 에 등록된 Secret text 의 ID. 값은 vault 복호화 비밀번호 하나뿐이다. 빌드 시 ansible-playbook 한테 `--vault-password-file` 로 자동 전달된다.

서버 계정 (`ansible_user` / `ansible_password`) 자체는 `vault/linux.yml` 에 ansible-vault 로 암호화되어 들어가 있고, playbook 이 `vars_files` 로 로딩하면 ansible 이 위 비밀번호로 자동 복호화한다.

그래서 `withCredentials([ usernamePassword(...) ])` 로 사용자/비번을 직접 꺼내거나, `extraVars` 에 비밀번호를 박는 패턴은 쓰지 않는다 — Jenkinsfile 이 시크릿 값을 직접 만지지 않게 함.

## Jenkins Credentials 등록 (1회)

Manage Jenkins → Credentials → System → Global → Add Credentials

- Kind: **Secret text**
- ID: **`ansible-vault-password`**
- Secret: vault 비밀번호 (`./scripts/encrypt-vault.sh` 실행 시 입력한 그 값)

이 ID 가 Jenkinsfile 의 `vaultCredentialsId` 와 정확히 일치해야 한다.
