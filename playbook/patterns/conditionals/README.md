# patterns/conditionals — 조건에 맞는 호스트에서만 task 실행하기

`when:` 은 task 옆에 붙이는 실행 조건이다.
조건이 참인 호스트에서는 task 가 실행되고, 조건이 거짓인 호스트에서는 `skipping` 으로 넘어간다.

## 왜 필요한가

운영 자동화에서는 모든 서버에 같은 작업을 실행하면 위험한 경우가 많다.
예를 들어 RHEL 9 서버에만 적용해야 하는 설정을 RHEL 8 서버에서까지 실행하면 불필요한 실패 로그가 쌓일 수 있다.
prod 환경에서만 알림을 보내거나, 메모리가 큰 서버에서만 특정 옵션을 켜야 할 때도 있다.
Jenkins 에서는 shell `if` 나 stage 조건으로 나누던 판단을, Ansible 에서는 task 옆의 `when:` 으로 처리한다.

## 먼저 알아둘 말

- `task` — Ansible 이 실행하는 작업 한 단계다.
- `fact` — Ansible 이 대상 서버에서 수집한 OS, CPU, 메모리 같은 기본 정보다.
- `gather_facts: true` — play 시작 전에 대상 서버의 fact 를 먼저 수집한다.
- `skipping` — 실패가 아니라, 조건이 맞지 않아 실행하지 않았다는 뜻이다.

## 최소 예제

RedHat 계열 서버에서만 메시지를 출력한다.

```yaml
- name: RedHat 계열에서만 실행
  ansible.builtin.debug:
    msg: "이 서버는 RedHat 계열입니다."
  when: ansible_facts.os_family == 'RedHat'
```

`when:` 오른쪽 조건이 참이면 task 가 실행된다.
RHEL 9 서버에서는 `ansible_facts.os_family` 값이 보통 `RedHat` 이므로 이 task 가 실행된다.
조건이 거짓이면 task 는 실패하지 않고 `skipping` 으로 표시된다.

## 전체 예제 흐름

`site.yml` 은 OS 계열 → RHEL 메이저 버전 → 메모리 값 → 다중 AND 조건 순으로 분기를 보여준다.

```yaml
- name: conditionals 데모 — when 으로 OS family·값·결과 기반 분기
  hosts: all
  gather_facts: true

  tasks:
    - name: RedHat 계열에서만 실행
      when: ansible_facts.os_family == 'RedHat'

    - name: RHEL 9 에서만 실행
      when:
        - ansible_facts.os_family == 'RedHat'
        - ansible_facts.distribution_major_version == '9'

    - name: RHEL 8 에서만 실행
      when:
        - ansible_facts.os_family == 'RedHat'
        - ansible_facts.distribution_major_version == '8'

    - name: 메모리 8 GB 이상에서만 실행
      when: ansible_facts.memtotal_mb >= 8192
```

실행 순서는 다음과 같다.

1. 대상 서버에 접속한다.
2. `gather_facts: true` 에 따라 OS 와 하드웨어 정보를 수집한다.
3. `os_family` 값으로 RedHat 계열 task 를 평가한다.
4. RedHat 계열이면서 major version 이 9 인 host 에서만 RHEL 9 task 가 실행된다.
5. 메모리 값에 따라 메모리 조건 task 가 갈린다.
6. 조건이 맞지 않는 task 는 `skipping` 으로 넘어간다.

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
  playbook/patterns/conditionals/site.yml
```

### 기대 결과

RHEL 9 서버에서 실행하면 다음과 비슷하게 나온다.

```text
TASK [RedHat 계열에서만 실행] **************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: RHEL 계열 (RedHat 9.x)"
}

TASK [RHEL 9 에서만 실행] *****************************
ok: [rhel9-dev-01]

TASK [RHEL 8 에서만 실행] *****************************
skipping: [rhel9-dev-01]

PLAY RECAP ********************************************
rhel9-dev-01 : ok=4 changed=0 skipped=2
```

조건이 맞지 않는 task 는 실패가 아니라 `skipping` 으로 표시된다.
같은 playbook 을 다시 돌려도 `debug` 중심이라 상태를 바꾸지 않으므로 결과는 같다.

## 자주 쓰는 모양

| 상황 | 예시 |
|---|---|
| 단일 조건 | `when: ansible_facts.os_family == 'RedHat'` |
| 여러 조건이 모두 참 | `when:` 아래 리스트로 작성 |
| 둘 중 하나만 참이면 실행 | `when: condition_a or condition_b` |
| 조건을 반대로 적용 | `when: not maintenance_mode` |
| 변수가 정의됐을 때만 실행 | `when: my_var is defined` |
| 이전 task 가 성공했을 때 | `when: result is succeeded` |
| 이전 task 가 실패했을 때 | `when: result is failed` |
| check mode 가 아닐 때 | `when: not ansible_check_mode` |

여러 조건이 모두 참이어야 할 때는 한 줄에 길게 쓰기보다 리스트 형태가 읽기 쉽다.

```yaml
when:
  - ansible_facts.os_family == 'RedHat'
  - ansible_facts.distribution_major_version == '9'
```

## 막힐 때 확인

> 증상: 모든 task 가 `skipping` 으로 나온다.
>
> 확인할 것:
> - `ansible_facts.os_family` 값이 실제로 무엇인지 먼저 확인한다.
> - 문자열 대소문자가 맞는지 확인한다. 예: `RedHat`
> - `gather_facts: true` 가 설정되어 있는지 확인한다.
> - 조건에 쓰는 변수가 정의되어 있는지 확인한다.

fact 값을 확인하고 싶다면 아래 task 를 임시로 추가한다.

```yaml
- name: OS 계열만 확인
  ansible.builtin.debug:
    var: ansible_facts.os_family
```

전체를 보고 싶을 때는 `var: ansible_facts` 로 바꾸면 된다.

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/` — OS 계열 분기 후 dnf/yum 으로 보안 패치 적용.
- `tasks/linux/sshd-safe-reload/` — `ansible_check_mode` 같은 메타 변수에 따라 실제 변경 task 를 건너뛴다.
- `patterns/register-when/` — 이전 task 결과를 `register` 로 잡아두고 `when:` 에서 다시 사용하는 패턴.
- `sandbox/user01/pre.yml` — RHEL 9 인지 확인하고 통과한 호스트만 다음 단계로.
