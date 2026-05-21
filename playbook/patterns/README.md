# patterns/ — Ansible 문법·구조 데모

`tasks/` 가 "**무엇을 하는가**" 라면 `patterns/` 는 "**Ansible 의 이 문법은 어떻게 생겼는가**" 를 보여주는 자리.

학습용이라 Jenkinsfile 없이 **작은 site.yml + README.md** 한 쌍으로만 구성. 실제 운영에서는 `tasks/` 안의 같은 패턴을 쓰는 예시를 복사해서 시작하면 된다.

## 데모 목록

| 디렉토리 | 보여주는 패턴 | 실제 작업에서 같은 패턴을 쓰는 예시 |
|---------|--------------|----------------------------------|
| [`roles/`](roles/) | Role 디렉토리 구조 (`roles/{name}/tasks,handlers,defaults,templates`) | [`tasks/linux/baseline/`](../tasks/linux/baseline/) |
| [`block-rescue/`](block-rescue/) | `block` → `rescue` → `always` 로 실패 시 자동 롤백 | [`tasks/linux/sshd-safe-reload/`](../tasks/linux/sshd-safe-reload/) |
| [`tags/`](tags/) | `tags` 로 같은 playbook 을 단계별 부분 실행 | [`tasks/linux/nginx-healthcheck/`](../tasks/linux/nginx-healthcheck/) |

## 직접 실행해보기

각 데모는 ansible-playbook 으로 단독 실행 가능 (인벤토리는 자유):

```
ansible-playbook -i inventory.ini playbook/patterns/{이름}/site.yml --ask-vault-pass
```

타겟에 변경을 일으키지 않거나, `/tmp` 같이 안전한 경로에만 쓰도록 작성돼 있음.
