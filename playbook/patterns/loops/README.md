# patterns/loops — loop 로 반복 처리

같은 task 를 **여러 항목에 대해 반복** 실행하는 패턴. 단순 리스트, dict 리스트, `loop_control` 로 출력 다듬기 등 자주 쓰는 형태를 한 곳에서 보여준다.

## 데모 시나리오

`/tmp/loop-demo/` 안에:
1. **단순 리스트 loop** — `alpha.flag`, `beta.flag`, `gamma.flag` 3 개 빈 파일
2. **dict 리스트 loop** — `hello.txt`, `bye.txt`, `thx.txt` 3 개 텍스트 파일 (각각 다른 내용)

마지막에 `find` 모듈로 결과를 모아 출력.

## 자주 쓰는 형태

```yaml
# 단순 리스트
loop:
  - alpha
  - beta

# dict 리스트 — item.name, item.body 로 접근
loop:
  - { name: hello, body: "안녕" }
  - { name: bye,   body: "잘 가" }

# 출력 라벨만 짧게 (전체 dict 가 로그에 찍히는 거 방지)
loop_control:
  label: "{{ item.name }}"

# loop_var 로 item 이름 바꾸기 (중첩 loop 에서 유용)
loop_control:
  loop_var: pkg

# 이전 결과를 다른 task 에서 loop 으로 (예: register 결과의 .results)
loop: "{{ prev_result.results }}"
```

## 주의할 점

- 옛 문법인 `with_items` / `with_dict` 는 **`loop:` 로 통일**된 게 모던 컨벤션
- `loop_control.label` 없이 dict loop 을 돌리면 출력이 매우 지저분해진다 — 거의 항상 같이 쓰는 게 좋다
- 매우 큰 리스트는 한 task 안에서 loop 보다 `community.general.batch` 같은 모듈이 빠른 경우도 있음

## 언제 쓰나

- 여러 user / group / package / service 를 한 task 로 처리
- file/directory 여러 개를 같은 옵션으로 만들기
- 이전 task 의 register 결과 (`.results`) 를 순회

## 실제 작업에서 같은 패턴 보기

- [`tasks/linux/baseline/`](../../tasks/linux/baseline/) 의 chrony role 에서 `loop:` 으로 servers 등록
- [`patterns/import-include/`](../import-include/) — `include_tasks` 와 `loop:` 조합 예시
