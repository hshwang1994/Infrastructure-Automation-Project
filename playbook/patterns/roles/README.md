# patterns/roles — task 묶음을 재사용 가능한 단위로 분리하기

`role` 은 task, 변수, handler, template 을 정해진 폴더 구조로 묶어 재사용하기 쉽게 만든 단위다.
playbook 은 `roles:` 한 줄만 쓰고, 본체는 role 디렉토리 안에 들어간다.

## 왜 필요한가

운영 자동화에서는 "chrony 설치 + 설정 + 재시작" 같은 묶음을 여러 playbook 에서 반복해서 쓰는 일이 잦다.
같은 task 를 매번 복붙하면 한 곳을 고쳐도 다른 곳을 빼먹기 쉽고, playbook 자체가 길어져 한눈에 안 들어온다.
`role` 은 그 묶음을 한 디렉토리에 정리해두고, playbook 에서 이름만 부르면 되도록 만든다.
프로그래밍 언어의 함수·라이브러리에 가까운 구조다.
Jenkins shared library 가 stage 별 공통 코드를 한곳에 두는 방식과 비슷하다고 보면 된다.

## 먼저 알아둘 말

- `roles:` 리스트 — playbook 의 최상위 키워드. 이 안에 role 이름을 적으면 해당 role 의 `tasks/main.yml` 이 자동 실행된다.
- `tasks/main.yml` — role 의 실제 작업이 들어가는 본체 파일이다.
- `defaults/main.yml` — role 안에서 쓰는 변수의 기본값이다. 호출하는 쪽에서 덮어쓸 수 있다.
- `handlers/main.yml` — role 안 task 의 `notify:` 가 호출하는 handler 묶음이다.

## 최소 예제

playbook 본문은 짧고, role 이름만 적는다.

```yaml
- name: Role 구조 데모
  hosts: all
  roles:
    - welcome
```

Ansible 은 같은 폴더의 `roles/welcome/` 을 자동으로 찾는다.
그 안의 `tasks/main.yml` 이 실행되고, `defaults/main.yml` 의 변수 기본값이 자동으로 들어간다.

## 전체 예제 흐름

이 데모의 디렉토리 구조는 다음과 같다.

```
roles/
├── site.yml
└── roles/
    └── welcome/
        ├── tasks/main.yml      실제 task
        ├── defaults/main.yml   변수 기본값
        └── handlers/main.yml   notify 로 호출되는 handler
```

`tasks/main.yml` 에는 두 task 가 있다.

```yaml
- name: 인사 메시지 출력
  ansible.builtin.debug:
    msg: "{{ welcome_message }} — host={{ inventory_hostname }}"

- name: 기록 파일 작성
  ansible.builtin.copy:
    content: "{{ welcome_message }}\n"
    dest: /tmp/welcome.txt
    mode: '0644'
  notify: log welcome
```

`defaults/main.yml` 에는 변수 기본값이 들어 있다.

```yaml
welcome_message: "hello from welcome role"
```

`handlers/main.yml` 에는 `notify: log welcome` 이 호출하는 handler 가 있다.

```yaml
- name: log welcome
  ansible.builtin.debug:
    msg: "welcome.txt 갱신됨"
```

실행 순서는 다음과 같다.

1. playbook 의 `roles: [welcome]` 이 role 디렉토리를 가리킨다.
2. `defaults/main.yml` 이 `welcome_message` 기본값을 채운다.
3. `tasks/main.yml` 의 `debug` task 가 메시지를 출력한다.
4. `copy` task 가 `/tmp/welcome.txt` 를 만든다. 내용이 바뀐 경우에만 `changed`.
5. `notify` 가 발동되어 마지막에 `log welcome` handler 가 한 번 실행된다.

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
# 기본 메시지로 실행
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/roles/site.yml

# 변수 override (defaults 의 기본값을 덮어씀)
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/roles/site.yml \
  -e "welcome_message=안녕"
```

### 기대 결과 (첫 실행)

```text
TASK [welcome : 인사 메시지 출력] **************************
ok: [rhel9-dev-01] => {
    "msg": "hello from welcome role — host=rhel9-dev-01"
}

TASK [welcome : 기록 파일 작성] **************************
changed: [rhel9-dev-01]

RUNNING HANDLER [welcome : log welcome] ******************
ok: [rhel9-dev-01] => {
    "msg": "welcome.txt 갱신됨 (rhel9-dev-01)"
}

PLAY RECAP **********************************************
rhel9-dev-01 : ok=3 changed=1
```

task 이름 앞에 `welcome :` 가 붙는 게 role 안에서 실행되었다는 표시다.

## 두 번째 실행에서 볼 것

같은 변수로 다시 돌리면 파일 내용이 동일하므로 `copy` task 가 `ok` 로 끝난다.
`notify` 가 예약되지 않아 handler 가 호출되지 않는다.

```text
TASK [welcome : 기록 파일 작성] **************************
ok: [rhel9-dev-01]

PLAY RECAP **********************************************
rhel9-dev-01 : ok=2 changed=0
```

`-e "welcome_message=안녕"` 으로 override 하면 내용이 달라져 다시 `changed=1` + handler 호출 흐름이 된다.
role 단위에서도 멱등성 동작이 그대로 유지된다는 점이 두 번째 실행에서 잘 보인다.

## 자주 쓰는 모양 (role 디렉토리·호출)

| 디렉토리 | 용도 |
|---|---|
| `tasks/main.yml` | role 의 실제 작업 (필수) |
| `defaults/main.yml` | 호출하는 쪽에서 덮어쓰기 쉬운 기본값 |
| `vars/main.yml` | 덮어쓰기 어려운 내부 상수 (우선순위 높음) |
| `handlers/main.yml` | `notify` 가 호출하는 handler |
| `templates/*.j2` | `template:` 모듈이 자동으로 찾는 위치 |
| `files/*` | `copy:` 모듈이 자동으로 찾는 위치 |
| `meta/main.yml` | role 메타 정보 (의존 role 등) |

## role 호출 방식 비교

| 방식 | 예시 | 특징 |
|---|---|---|
| 표준 `roles:` 키 | `roles: [welcome]` | play 시작 시 자동 적용 |
| `import_role` | `- import_role: name=welcome` | 정적, 파싱 시점에 합쳐짐 |
| `include_role` | `- include_role: name=welcome` | 동적, 실행 시점에 평가 — `loop`, `when` 과 같이 쓰기 좋음 |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/baseline/` — `chrony` role 과 `motd` role 두 개를 묶어 baseline 구성을 만든다. `site.yml` 이 `roles: [chrony, motd]` 한 줄로 끝난다.
- `patterns/handlers/` — role 안 `tasks/main.yml` 의 `notify` 와 `handlers/main.yml` 이 한 쌍으로 동작하는 패턴과 짝이 된다.
- `patterns/import-include/` — `include_role` 과 `loop:` 을 같이 써서 같은 role 을 환경별로 여러 번 부르는 흐름.
