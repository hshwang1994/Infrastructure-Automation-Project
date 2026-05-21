# patterns/loops — 같은 task 를 여러 번 반복

user 10명을 만들거나, service 5개를 일괄로 띄우거나, config 파일 여러 개를 한 번에 배포해야 할 때 같은 task 를 10번 복붙하면 코드가 지저분해진다. `loop:` 키워드는 **한 task 를 여러 항목에 대해 반복** 실행해준다.

## 동작 흐름

```yaml
- name: 단순 리스트
  ansible.builtin.file:
    path: "/tmp/{{ item }}.flag"
    state: touch
  loop:
    - alpha
    - beta
    - gamma
```

각 반복마다 `item` 변수에 현재 항목이 들어간다. task 안에서 `{{ item }}` 으로 꺼내 쓰면 된다.

dict 항목으로 돌리고 싶으면:

```yaml
loop:
  - { name: hello, body: "안녕" }
  - { name: bye,   body: "잘 가" }
# 안에서 {{ item.name }}, {{ item.body }} 로 접근
```

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

`/tmp/loop-demo/` 안에 6개 파일 (alpha/beta/gamma.flag + hello/bye/thx.txt) 이 만들어지고, 마지막 task 가 그 결과를 한꺼번에 출력한다.

## `loop_control: label` 은 왜 쓰나

dict 를 loop 으로 돌리면 로그가 너무 시끄럽다:

```
[host1] => (item={'name': 'hello', 'body': '안녕'})
[host1] => (item={'name': 'bye',   'body': '잘 가'})
```

`loop_control: label: "{{ item.name }}"` 한 줄 추가하면 깔끔해진다:

```
[host1] => (item=hello)
[host1] => (item=bye)
```

dict loop 에서는 거의 항상 같이 쓴다.

## 알아두면 좋은 것

- 옛 문법 `with_items` / `with_dict` 는 이제 `loop:` 로 통일하는 게 모던 컨벤션
- `register` 한 task 에 loop 가 있으면 결과가 `.results` 리스트로 들어옴 (그걸 다시 loop 으로 돌 수도 있음)

## 실제 작업에서 어디 쓰이나

- `tasks/linux/baseline/` 의 chrony role — 여러 NTP 서버를 loop 으로 등록
- `patterns/import-include/` — `include_tasks` 와 `loop:` 을 같이 쓰는 예시
