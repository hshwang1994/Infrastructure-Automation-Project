# Agent 셋업 가이드 — ansible.cfg + 인벤토리 스크립트

Jenkins Agent 한 대를 새로 만들 때 한 번 따라하면 되는 셋업 절차.

목표: 빌드할 때마다 Jenkinsfile 이 `inventory` 경로를 적지 않아도, ansible 이 자동으로 `inventory/my_inventory.sh` 를 사용하도록 만든다.

## 0. 시스템 의존성

password 기반 SSH 와 sudo 를 ansible 이 처리하려면 `sshpass` 가 필요하다. 미설치 상태에서 password 인증으로 돌리면 `[ERROR]: A worker was found in a dead state` 로 실패한다.

```bash
sudo apt-get install -y sshpass
which sshpass    # /usr/bin/sshpass
```

vault 가 SSH 비밀번호를 들고 있어도 ansible 이 내부적으로 sshpass 를 호출하므로, vault 만 쓰는 셋업이어도 필수다. (ansible-core 2.20.3 에서 확인)

## 1. 인벤토리 스크립트를 Agent 에 복사

```bash
git clone https://github.com/hshwang1994/Infrastructure-Automation-Project.git /tmp/repo

sudo mkdir -p /opt/ansible-env/inventory
sudo cp /tmp/repo/inventory/my_inventory.sh /opt/ansible-env/inventory/my_inventory.sh
sudo chmod +x /opt/ansible-env/inventory/my_inventory.sh

ls -la /opt/ansible-env/inventory/my_inventory.sh
# -rwxr-xr-x ... /opt/ansible-env/inventory/my_inventory.sh
```

저장소의 `inventory/my_inventory.sh` 가 "원본", Agent 의 `/opt/ansible-env/inventory/my_inventory.sh` 가 "실제 실행되는 파일". 스크립트를 수정하면 각 Agent 에 다시 복사해야 한다.

## 2. `/etc/ansible/ansible.cfg` 작성

Agent 의 시스템 ansible.cfg 가 인벤토리 경로를 가리키게 한다. 이미 다른 설정이 있으면 `inventory` 라인만 추가/수정.

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

`{Jenkins_마스터_IP}`, `{Redis비밀번호}` 는 실제 값으로 교체.

## 3. 설정이 먹혔는지 확인

```bash
/opt/ansible-env/bin/ansible-config dump | grep DEFAULT_HOST_LIST
# DEFAULT_HOST_LIST(/etc/ansible/ansible.cfg) = ['/opt/ansible-env/inventory/my_inventory.sh']
```

이 줄이 나오면 끝.

## Jenkinsfile 에서 inventory 라인을 빼도 되는 이유

위 셋업이 되어 있으면 `ansiblePlaybook()` 호출에서 `inventory` 파라미터를 생략해도 ansible 이 알아서 `/etc/ansible/ansible.cfg` 의 경로를 사용한다.

```groovy
// inventory 안 적음 — ansible.cfg 가 처리
ansiblePlaybook(
    installation: 'ansible',
    playbook    : "${WORKSPACE}/playbook/{작업}/site.yml",
    colorized   : true
)
```

## ansible.cfg 우선순위 (참고)

ansible 은 여러 위치에 ansible.cfg 가 있어도 **병합하지 않고 가장 높은 우선순위 하나만** 사용한다.

| 우선순위 | 경로 |
|---------|------|
| 1 | `ANSIBLE_CONFIG` 환경변수가 가리키는 경로 |
| 2 | 현재 디렉토리의 `ansible.cfg` |
| 3 | `~/.ansible.cfg` |
| 4 | `/etc/ansible/ansible.cfg` |

이 저장소 루트에는 `ansible.cfg` 를 두지 않는다 — 만약 두면 Jenkins 가 checkout 한 디렉토리에서 ansible 을 실행할 때 그게 우선되어 Agent 의 `/etc/ansible/ansible.cfg` 가 무시된다.
