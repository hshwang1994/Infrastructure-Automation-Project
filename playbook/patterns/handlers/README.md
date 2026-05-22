# patterns/handlers — 설정이 바뀌었을 때만 서비스 재시작

`handler` 는 task 가 실제로 변경(`changed`)을 만들었을 때만 호출되는 후속 task 다.
설정 파일이 그대로면 호출되지 않고, 바뀐 경우에만 한 번 실행된다.

## 왜 필요한가

운영 자동화에서는 같은 playbook 을 반복해서 실행하는 일이 잦다.
이때 `nginx.conf`, `sshd_config`, `chrony.conf` 같은 설정 파일을 고치면 그 서비스를 재시작해야 새 설정이 적용된다.
그렇다고 playbook 을 돌릴 때마다 무조건 재시작하면 잠깐 서비스가 끊기고, 동시에 많은 호스트에서 같은 일이 벌어지면 더 위험하다.
`handler` 는 "설정이 실제로 바뀐 호스트에서만" 재시작이 일어나도록 묶는 장치다.
Jenkins 에서 shell `if grep changed ...; then service restart` 로 분기하던 패턴을 task 단위로 자연스럽게 표현한다고 보면 된다.

## 먼저 알아둘 말

- `notify` — task 가 `changed` 로 끝났을 때 같은 이름의 handler 를 호출 예약하는 키워드다.
- `handler` — `notify` 를 받은 경우에만 play 의 끝에서 한 번 실행되는 task 다.
- `changed` vs `ok` — task 가 시스템을 실제로 바꿨으면 `changed`, 이미 원하던 상태였으면 `ok` 다.

## 최소 예제

설정 파일을 배치하고, 내용이 바뀐 경우에만 handler 를 호출한다.

```yaml
- name: 설정 파일 배치
  ansible.builtin.copy:
    content: "key=value\n"
    dest: /tmp/handlers-demo.conf
    mode: '0644'
  notify: log config changed

handlers:
  - name: log config changed
    ansible.builtin.debug:
      msg: "설정이 바뀌어서 핸들러 호출됨"
```

`copy` task 의 결과가 `changed` 면 `log config changed` handler 가 예약된다.
같은 내용으로 다시 돌리면 `copy` task 는 `ok` 로 끝나고 handler 는 호출되지 않는다.

## 전체 예제 흐름

`site.yml` 은 다음 흐름으로 구성된다.

```yaml
tasks:
  - name: 설정 파일 배치
    ansible.builtin.copy:
      content: "{{ config_body }}\n"
      dest:    "{{ config_path }}"
      mode:    '0644'
    notify: log config changed

  - name: 결과 출력
    ansible.builtin.debug:
      msg: "{{ inventory_hostname }}: 설정 파일 {{ config_path }} 적용 시도 완료"

handlers:
  - name: log config changed
    ansible.builtin.debug:
      msg: "{{ inventory_hostname }}: 설정이 바뀌어서 핸들러 호출됨"
```

실행 순서는 다음과 같다.

1. 컨트롤러가 `config_body` 내용을 대상 호스트의 `config_path` 로 복사한다.
2. 파일이 바뀌면 `copy` task 는 `changed` 로 끝나고 `log config changed` handler 를 예약한다.
3. 그 뒤 `debug` task 가 실행된다.
4. play 의 모든 task 가 끝난 뒤, 예약된 handler 가 호출된다.
5. 두 번째 실행에서 같은 내용이면 `copy` 는 `ok` 로 끝나고 handler 는 호출되지 않는다.

## 직접 돌려보기

### 실행 전 확인

- 대상 서버: Linux (RHEL 9 계열)
- Ansible: 2.15 이상
- 동적 인벤토리: `inventory/my_inventory.sh`
- 환경변수:
  ```bash
  export TARGET_TYPE=linux
  export INVENTORY_JSON='[{"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"}]'
  ```

```bash
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/handlers/site.yml
```

### 기대 결과 (첫 실행)

```text
TASK [설정 파일 배치] *********************************
changed: [rhel9-dev-01]

TASK [결과 출력] ************************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 설정 파일 /tmp/handlers-demo.conf 적용 시도 완료"
}

RUNNING HANDLER [log config changed] ****************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 설정이 바뀌어서 핸들러 호출됨 (실제로는 여기서 service 재시작)"
}

PLAY RECAP ******************************************
rhel9-dev-01 : ok=3 changed=1
```

`changed=1` 옆에 `RUNNING HANDLER` 한 줄이 같이 나오면 정상이다.

## 두 번째 실행에서 볼 것

같은 명령을 한 번 더 돌리면 파일 내용이 그대로라서 `copy` task 가 `ok` 로 끝난다.
`notify` 자체가 예약되지 않으므로 `RUNNING HANDLER` 줄은 아예 나오지 않는다.

```text
TASK [설정 파일 배치] *********************************
ok: [rhel9-dev-01]

PLAY RECAP ******************************************
rhel9-dev-01 : ok=2 changed=0
```

`config_body` 값을 바꿔서(예: `key=value2`) 다시 돌리면 다시 `changed=1` + handler 호출 흐름이 된다.
"바뀐 호스트에서만 handler 가 돈다" 는 멱등성 동작은 두 번째 실행에서 가장 잘 보인다.

## 자주 쓰는 모양

| 상황 | task 측 | handler 측 |
|---|---|---|
| nginx 설정 변경 시 reload | `copy: ... dest: /etc/nginx/nginx.conf` + `notify: reload nginx` | `ansible.builtin.service: name=nginx state=reloaded` |
| sshd 설정 변경 시 restart | `template: ... dest: /etc/ssh/sshd_config` + `notify: restart sshd` | `ansible.builtin.service: name=sshd state=restarted` |
| chrony 설정 변경 시 restart | `copy: ... dest: /etc/chrony.conf` + `notify: restart chronyd` | `ansible.builtin.service: name=chronyd state=restarted` |
| 여러 task 가 같은 handler 호출 | task 여러 개에서 같은 `notify: ...` 사용 | handler 는 한 번만 호출됨 (마지막에 1회) |
| 즉시 실행이 필요할 때 | task 다음 줄에 `meta: flush_handlers` | 그 시점에 예약된 handler 가 바로 실행됨 |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/nginx-healthcheck/` — `nginx.conf` 가 바뀐 경우에만 nginx 를 재시작한다.
- `tasks/linux/baseline/` — `chrony.conf` 가 바뀐 경우에만 `chronyd` 를 재시작한다.
- `patterns/roles/` — role 안에서도 같은 방식으로 `tasks/main.yml` 의 `notify:` 와 `handlers/main.yml` 이 한 쌍으로 동작한다.
