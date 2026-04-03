# 인벤토리 스크립트 Agent 배치 가이드

## 개요

인벤토리 스크립트(`my_inventory.sh`)를 Agent 에 고정 배치하고,
`/etc/ansible/ansible.cfg` 에 경로를 등록하면
Jenkinsfile 에서 `inventory` 파라미터를 생략할 수 있다.

## 배치 절차

### 1. Agent 에 스크립트 복사

Git 에서 원본을 가져와 Agent 에 배치한다.

```bash
# 프로젝트 clone (또는 기존 clone 에서 pull)
git clone https://github.com/hshwang1994/Infrastructure-Automation-Project.git /tmp/repo

# 인벤토리 스크립트 배치
sudo mkdir -p /opt/ansible-env/inventory
sudo cp /tmp/repo/inventory/my_inventory.sh /opt/ansible-env/inventory/my_inventory.sh
sudo chmod +x /opt/ansible-env/inventory/my_inventory.sh

# 확인
ls -la /opt/ansible-env/inventory/my_inventory.sh
# -rwxr-xr-x ... /opt/ansible-env/inventory/my_inventory.sh
```

### 2. `/etc/ansible/ansible.cfg` 에 inventory 경로 추가

기존 Agent 설정 문서(03. Agent 노드 구성) 6번 항목의 ansible.cfg 에
`inventory` 줄을 추가한다.

```ini
[defaults]
inventory               = /opt/ansible-env/inventory/my_inventory.sh
host_key_checking       = False
bin_ansible_callbacks   = True
retry_files_enabled     = False
gathering               = smart
interpreter_python      = auto
forks                   = 20
timeout                 = 60
deprecation_warnings    = False
fact_caching            = redis
fact_caching_connection = {Jenkins_마스터_IP}:6379:0:{Redis비밀번호}
fact_caching_timeout    = 86400

[inventory]
enable_plugins = script, auto

[ssh_connection]
pipelining = True

[winrm]
transport = ntlm
```

> `{Jenkins_마스터_IP}`, `{Redis비밀번호}` 는 실제 값으로 교체한다.

### 3. 동작 확인

```bash
# ansible.cfg 에서 인벤토리 경로 인식 확인
/opt/ansible-env/bin/ansible-config dump | grep DEFAULT_HOST_LIST
# DEFAULT_HOST_LIST(/etc/ansible/ansible.cfg) = ['/opt/ansible-env/inventory/my_inventory.sh']
```

## Jenkinsfile 변경 사항

`ansiblePlaybook()` 호출에서 `inventory` 파라미터를 생략한다.
Ansible 이 `/etc/ansible/ansible.cfg` 의 `inventory` 설정을 자동으로 사용한다.

```groovy
// Before — inventory 매번 명시
ansiblePlaybook(
    installation: 'ansible',
    playbook    : "${WORKSPACE}/playbooks/작업경로/site.yml",
    inventory   : "${WORKSPACE}/inventory/my_inventory.sh",
    colorized   : true
)

// After — inventory 생략
ansiblePlaybook(
    installation: 'ansible',
    playbook    : "${WORKSPACE}/playbooks/작업경로/site.yml",
    colorized   : true
)
```

## 스크립트 업데이트

`my_inventory.sh` 를 수정한 경우 Agent 에 재배포해야 한다.

```bash
# 수정된 스크립트를 Agent 에 반영
cd /tmp/repo && git pull
sudo cp /tmp/repo/inventory/my_inventory.sh /opt/ansible-env/inventory/my_inventory.sh
sudo chmod +x /opt/ansible-env/inventory/my_inventory.sh
```

Agent 가 여러 대인 경우 각 Agent 마다 반복한다.

> Git 의 `inventory/my_inventory.sh` 는 원본(버전 관리)으로 유지한다.
> Agent 에 배치된 파일이 실제 실행되는 파일이다.

## ansible.cfg 우선순위 참고

Ansible 은 설정 파일을 **병합하지 않고** 우선순위 1개만 사용한다.

| 우선순위 | 경로 |
|---------|------|
| 1 | `ANSIBLE_CONFIG` 환경변수 |
| 2 | CWD 의 `ansible.cfg` |
| 3 | `~/.ansible.cfg` |
| 4 | `/etc/ansible/ansible.cfg` |

현재 프로젝트 루트에 `ansible.cfg` 가 없으므로
Jenkins checkout 후 CWD 에 설정 파일이 없어 `/etc/ansible/ansible.cfg` 가 적용된다.

> 프로젝트 루트에 `ansible.cfg` 를 추가하면 `/etc/ansible/ansible.cfg` 가 무시된다.
> 특별한 사유가 없는 한 프로젝트 루트에 `ansible.cfg` 를 두지 않는다.

## Git 실행 권한 참고

Agent 고정 배치 방식에서는 `chmod +x` 를 직접 실행하므로
Git 실행 권한 문제가 발생하지 않는다.

단, Git 에서 직접 인벤토리를 사용하는 경우(프로젝트 상대경로 방식 등)에는
`git update-index --chmod=+x inventory/my_inventory.sh` 가 필요하다.
현재 프로젝트에는 이미 `100755` 로 커밋되어 있다.
