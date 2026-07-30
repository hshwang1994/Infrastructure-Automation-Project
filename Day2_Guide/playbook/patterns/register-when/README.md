# patterns/register-when — 이전 결과를 변수에 잡고 다음 task 분기하기

`register:` 는 task 의 실행 결과(성공·실패·출력값)를 변수에 저장한다.
그 변수를 다음 task 의 `when:` 에서 다시 보면, 앞 결과에 따라 분기를 만들 수 있다.

## 왜 필요한가

자동화 작업에서는 "앞 task 의 결과가 이러면 다음을 하고, 아니면 건너뛴다" 는 흐름이 자주 나온다.
파일이 이미 있으면 새로 만들지 않거나, 명령 출력에 특정 문자열이 있을 때만 다음 단계를 돌리는 식이다.
조건 분기에 필요한 값은 보통 OS fact 만으로는 부족하고, 직전 task 에서 직접 얻어와야 한다.
`register` + `when:` 은 이 흐름을 두 task 사이의 변수 전달로 깔끔하게 풀어준다.
Jenkins 에서 shell `out=$(cmd) && if grep ...; then` 로 처리하던 패턴이 그대로 옮겨온다고 보면 된다.

## 먼저 알아둘 말

- `register: 변수명` — 그 task 의 실행 결과 전체를 그 변수에 담는다.
- 결과 필드 — task 모듈마다 다르다. `.changed`, `.failed`, `.rc`, `.stdout`, `.stat` 같은 식.
- `changed_when: false` — `command` / `shell` 결과를 실제 변경으로 보지 않도록 표시한다 (조회용 호출에 자주 같이 쓴다).

## 최소 예제

파일 존재 여부를 확인한 뒤, 없을 때만 새로 만든다.

```yaml
- name: 파일 존재 확인
  ansible.builtin.stat:
    path: /tmp/register-demo.txt
  register: target_stat

- name: 파일이 없으면 만들기
  ansible.builtin.copy:
    content: "처음 실행에서 만들어진 파일\n"
    dest: /tmp/register-demo.txt
    mode: '0644'
  when: not target_stat.stat.exists
```

`stat` task 가 끝나면 `target_stat.stat.exists` 에 true/false 가 들어간다.
다음 task 의 `when: not target_stat.stat.exists` 가 그 값을 보고 실행 여부를 정한다.

## 전체 예제 흐름

`site.yml` 은 "파일 있는지 확인 → 분기 작성/안내 → 내용 다시 읽기 → 내용 조건으로 출력" 순서다.

```yaml
tasks:
  - name: 파일 존재 여부 확인
    ansible.builtin.stat:
      path: /tmp/register-demo.txt
    register: target_stat

  - name: 파일이 없으면 새로 만들기
    ansible.builtin.copy:
      content: "처음 실행에서 만들어진 파일\n"
      dest: /tmp/register-demo.txt
    when: not target_stat.stat.exists

  - name: 파일이 이미 있으면 안내만
    ansible.builtin.debug:
      msg: "이미 존재 — size={{ target_stat.stat.size }}B"
    when: target_stat.stat.exists

  - name: 현재 내용 읽기 (조회용)
    ansible.builtin.command: cat /tmp/register-demo.txt
    register: contents
    changed_when: false

  - name: 내용에 '처음' 이 포함될 때만 출력
    ansible.builtin.debug:
      msg: "첫 실행 후 상태 — {{ contents.stdout }}"
    when:
      - contents.rc == 0
      - "'처음' in contents.stdout"
```

실행 순서는 다음과 같다.

1. `stat` 으로 `/tmp/register-demo.txt` 의 메타 정보를 본다.
2. `target_stat.stat.exists` 가 false 면 `copy` 가 실행되고, true 면 `debug` 가 실행된다.
3. `command: cat ...` 의 결과를 `contents` 에 담는다.
4. `contents.rc == 0` 과 `'처음' in contents.stdout` 두 조건이 모두 참일 때만 마지막 출력이 실행된다.
5. 그 외 task 는 `skipping` 으로 넘어간다.

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
  playbook/patterns/register-when/site.yml
```

### 기대 결과 (첫 실행)

```text
TASK [파일 존재 여부 확인] ****************************
ok: [rhel9-dev-01]

TASK [파일이 없으면 새로 만들기] **********************
changed: [rhel9-dev-01]

TASK [파일이 이미 있으면 안내만] **********************
skipping: [rhel9-dev-01]

TASK [내용에 '처음' 이 포함될 때만 출력] **************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 첫 실행 후 상태 — 처음 실행에서 만들어진 파일"
}
```

두 번째 실행에서는 파일이 이미 있으므로 `copy` 가 `skipping`, `debug` 안내가 `ok` 로 뒤집힌다.
마지막 출력은 그대로 `'처음'` 이 포함되어 있어서 계속 보인다.

## 자주 쓰는 모양 (register 결과 필드 + when 표현)

| 필드 | 의미 |
|---|---|
| `.changed` | task 가 시스템을 바꿨는지 (true/false) |
| `.failed` | 실패했는지 |
| `.rc` | `command` / `shell` 의 return code |
| `.stdout` | `command` / `shell` 의 표준 출력 |
| `.stdout_lines` | `stdout` 을 줄 단위 리스트로 |
| `.stat` | `stat` 모듈 결과 (`exists`, `size`, `mode`, `mtime` 등) |
| `.results` | `loop:` 가 있는 task 의 항목별 결과 리스트 |

`when:` 안에서는 다음 표현이 자주 쓰인다.

```yaml
when: target_stat.stat.exists                # bool 필드
when: contents.rc == 0                       # 숫자 비교
when: "'특정문자열' in contents.stdout"        # 문자열 포함
when: contents.stdout_lines | length > 5     # 필터 + 비교
when:
  - 조건A
  - 조건B
```

## 막힐 때 확인

> 증상: `command` 를 `register` 했더니 항상 `changed=1` 으로 잡힌다.
>
> 확인할 것:
> - 조회만 하는 명령은 `changed_when: false` 를 같이 붙인다.
> - 시스템을 바꾸지 않는 task 인데 `changed` 가 떠 있으면 멱등성이 깨진다.
> - 실패가 정상인 경우라면 `failed_when:` 으로 실패 판정 기준을 명시한다.

> 증상: `target_stat.stat.exists` 같은 필드에서 "attribute 없음" 에러가 난다.
>
> 확인할 것:
> - `register` 한 task 의 결과 구조를 먼저 출력해서 확인한다.
>   ```yaml
>   - name: register 결과 구조 확인
>     ansible.builtin.debug:
>       var: target_stat
>   ```
> - 모듈마다 결과 필드가 다르다. `stat`, `slurp`, `command`, `service_facts` 는 각각 다른 모양의 결과를 돌려준다.

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/post.yml` — `service_facts` 결과를 `register` 해서 sshd 가 active 인지 검증한다.
- `tasks/linux/disk-check/` — `df` / `find` 명령을 `register` 해서 한꺼번에 `debug` 로 보고한다.
- `patterns/conditionals/` — fact 기반 `when:` 과 같이 비교하면 분기 패턴이 한눈에 들어온다.
- `sandbox/user01/post.yml` — `stat` 결과로 파일 존재를 검증해 작업 완료 여부를 확인한다.
