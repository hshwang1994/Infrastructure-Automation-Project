# patterns/loops — 같은 task 를 여러 항목에 반복 적용하기

`loop:` 은 task 한 개를 항목 목록만큼 반복 실행하는 방법이다.
같은 task 를 여러 번 복붙하지 않고도, 항목마다 살짝씩 다른 작업을 시킬 수 있다.

## 왜 필요한가

운영 자동화에서는 "여러 항목에 같은 작업"이 반복적으로 나온다.
예를 들어 사용자 10명 계정 생성, NTP 서버 4대 등록, 디렉토리 5개 만들기, 환경별 설정 파일 3종 배포 같은 식이다.
같은 task 를 항목 수만큼 복붙하면 코드 양만 늘고, 항목이 늘거나 줄 때마다 task 자체를 손봐야 한다.
`loop:` 은 항목 목록과 task 본문을 분리해서, 항목이 바뀌어도 task 본문은 그대로 두게 만든다.
Jenkins 의 `parallel { }` 나 shell `for` 루프가 한 작업을 여러 입력에 적용하던 자리를 그대로 차지한다.

## 먼저 알아둘 말

- `item` — loop 이 도는 동안 현재 항목 값이 자동으로 들어가는 변수다.
- `loop_control` — loop 출력 라벨이나 변수 이름을 조정하는 옵션 묶음이다.
- `register` + loop — loop 가 있는 task 의 결과는 `결과변수.results` 리스트에 항목별로 쌓인다.

## 최소 예제

세 개의 빈 파일을 한 task 로 만든다.

```yaml
- name: 단순 리스트 loop
  ansible.builtin.file:
    path:  "/tmp/loop-demo/{{ item }}.flag"
    state: touch
    mode:  '0644'
  loop:
    - alpha
    - beta
    - gamma
```

반복마다 `item` 에 `alpha`, `beta`, `gamma` 가 차례로 들어간다.
task 안에서 `{{ item }}` 을 쓰면 그 값을 그대로 꺼낼 수 있다.

## 전체 예제 흐름

`site.yml` 은 단순 리스트 loop → dict 리스트 loop → 결과 검증 흐름이다.

```yaml
tasks:
  - name: 작업 디렉토리 준비
    ansible.builtin.file:
      path:  /tmp/loop-demo
      state: directory
      mode:  '0755'

  - name: 단순 리스트 loop
    ansible.builtin.file:
      path:  "/tmp/loop-demo/{{ item }}.flag"
      state: touch
    loop: [alpha, beta, gamma]

  - name: dict 리스트 loop
    ansible.builtin.copy:
      content: "{{ item.body }}\n"
      dest:    "/tmp/loop-demo/{{ item.name }}.txt"
    loop:
      - { name: hello, body: "안녕하세요" }
      - { name: bye,   body: "잘 가요" }
      - { name: thx,   body: "고맙습니다" }
    loop_control:
      label: "{{ item.name }}"

  - name: 결과 확인
    ansible.builtin.find:
      paths:    /tmp/loop-demo
      patterns: "*"
    register: found
```

실행 순서는 다음과 같다.

1. `/tmp/loop-demo/` 디렉토리를 만든다.
2. 단순 리스트 loop 에서 3개의 `*.flag` 파일을 만든다.
3. dict 리스트 loop 에서 3개의 `*.txt` 파일을 만든다.
4. `find` 가 디렉토리 안 파일 6개를 모아 `found` 변수에 넣는다.
5. 마지막 `debug` task 가 만들어진 파일 경로를 정렬해서 출력한다.

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
  playbook/patterns/loops/site.yml
```

### 기대 결과

```text
TASK [단순 리스트 loop] *****************************
changed: [rhel9-dev-01] => (item=alpha)
changed: [rhel9-dev-01] => (item=beta)
changed: [rhel9-dev-01] => (item=gamma)

TASK [dict 리스트 loop] *****************************
changed: [rhel9-dev-01] => (item=hello)
changed: [rhel9-dev-01] => (item=bye)
changed: [rhel9-dev-01] => (item=thx)

TASK [만들어진 파일 목록 출력] ***********************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 6개 — ['/tmp/loop-demo/alpha.flag', ... '/tmp/loop-demo/thx.txt']"
}
```

`(item=hello)` 같은 짧은 라벨은 `loop_control: label` 효과다.
같은 명령을 두 번째로 돌리면 `file: state=touch` 는 mtime 만 갱신해서 `changed` 가 다시 뜨고, `copy` 는 내용이 같으므로 `ok` 로 끝난다.

## 자주 쓰는 모양

| 상황 | 예시 |
|---|---|
| 단순 리스트 | `loop: [a, b, c]` |
| dict 리스트 | `loop: [{name: a, port: 80}, {name: b, port: 81}]` + `{{ item.name }}` |
| 변수에 들어있는 리스트 | `loop: "{{ users }}"` |
| 출력 라벨 짧게 | `loop_control: label: "{{ item.name }}"` |
| `item` 이름 바꾸기 | `loop_control: loop_var: env_name` 후 `{{ env_name }}` 으로 접근 |
| 반복 결과 보관 | `register: results` 후 `results.results` 리스트 사용 |
| 조건부 반복 | `loop:` + 같은 task 에 `when:` (각 반복마다 조건 평가) |

## 막힐 때 확인

> 증상: `(item={'name': 'hello', 'body': '안녕하세요'})` 처럼 dict 전체가 그대로 출력돼서 로그가 시끄럽다.
>
> 확인할 것:
> - dict loop 에서는 거의 항상 `loop_control: label: "{{ item.<요약키> }}"` 를 같이 쓴다.
> - `loop_var` 를 바꾼 경우 task 본문의 `{{ item.* }}` 도 새 이름으로 같이 바꿔야 한다.
> - 옛 문법 `with_items` / `with_dict` 는 이제 `loop:` 로 통일한다. 같이 쓰지 말 것.

라벨만 짧게 바꿔도 출력이 한결 깨끗하다.

```yaml
loop_control:
  label: "{{ item.name }}"
```

## 실제 작업에서 어디 쓰이나

- `tasks/linux/baseline/` — chrony role 안에서 NTP 서버 여러 개를 `loop:` 으로 등록한다.
- `patterns/import-include/` — `include_tasks` 와 `loop:` 을 같이 써서 env 별로 task 파일을 동적으로 부른다.
- `patterns/register-when/` — `register` 한 결과를 다시 loop 으로 돌리는 흐름.
