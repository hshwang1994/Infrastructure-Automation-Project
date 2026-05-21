# patterns/register-when — 이전 결과를 기억해서 다음 분기에 쓰기

이전 task 의 결과(성공·실패·출력값)를 가지고 다음 task 가 다르게 동작해야 할 때가 많다:

- 파일이 이미 있으면 만들지 마라 (있는데 또 만들면 덮어쓰니까)
- 명령 stdout 에 특정 단어가 있으면 알림
- service 가 죽어 있으면 띄워라

이걸 표현하는 게 `register:` + `when:` 조합이다. `register` 로 결과를 변수에 담아두고, 다음 task 의 `when:` 에서 그 변수를 본다.

## 동작 흐름

```yaml
- name: 파일 존재 확인
  ansible.builtin.stat:
    path: /tmp/foo.txt
  register: target_stat       # 결과를 target_stat 에 담아둠

- name: 파일이 없으면 만들기
  ansible.builtin.copy:
    content: "..."
    dest: /tmp/foo.txt
  when: not target_stat.stat.exists   # 위 결과의 .exists 필드를 봄
```

`register` 된 변수는 task 마다 들어있는 필드가 다르다. 자주 쓰는 것:

| 필드            | 의미                                           |
|:----------------|:-----------------------------------------------|
| `.changed`      | task 가 시스템을 바꿨는지 (true/false)         |
| `.failed`       | 실패했는지                                     |
| `.rc`           | command/shell 의 return code                   |
| `.stdout`       | command/shell 의 표준출력                      |
| `.stdout_lines` | stdout 을 줄 단위 리스트로                     |
| `.stat`         | `stat` 모듈의 결과 (exists, size, mode 등)     |
| `.results`      | `loop:` 으로 돈 task 의 항목별 결과 리스트     |

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

두 번 돌려보면 차이가 보인다:

| 회차 | 무슨 일이 일어나나                                    |
|:---:|:------------------------------------------------------|
| 1   | 파일 없음 → 만들기 task 가 실행, 안내 task 는 skip     |
| 2   | 파일 있음 → 만들기 skip, 안내 task 가 실행             |

## `when:` 안에서 쓰는 흔한 표현

```yaml
when: target_stat.stat.exists                  # bool 필드 직접
when: contents.rc == 0                          # 숫자 비교
when: "'특정문자열' in contents.stdout"          # 문자열 포함
when: contents.stdout_lines | length > 5        # 필터 + 비교
when:
  - 조건A                                       # 리스트는 AND
  - 조건B
```

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/post.yml` — `service_facts` 결과를 register 해서 sshd 가 active 인지 확인
- `tasks/linux/disk-check/` — command 결과를 register 해서 한꺼번에 debug 출력
- `sandbox/` 의 `post.yml` — `stat` 결과로 파일 존재 검증
