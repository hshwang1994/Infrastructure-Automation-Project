# patterns/handlers — notify + handlers

config 파일이 **실제로 바뀐 경우에만** service 재시작 같은 후속 동작을 돌리는 패턴. `task` 가 `changed` 상태가 됐을 때만 `notify` 가 발동되고, `handlers` 에 정의된 같은 이름의 항목이 **play 끝에서 한 번** 실행된다.

## 데모 시나리오

`/tmp/handlers-demo.conf` 에 `key=value` 작성. 처음 실행하면 파일이 새로 생기니 `changed` → handler 호출. 두 번째 실행은 내용 동일하니 `ok` → handler 호출 안 됨. `vars.config_body` 를 바꾸고 다시 돌리면 다시 `changed` → handler 호출.

## 언제 쓰나

- **service 재시작이 비싸거나 위험할 때** — config 가 안 바뀌었으면 재시작 안 시키고 싶음
- **여러 task 가 같은 service 를 건드릴 때** — 각 task 가 `notify` 만 하고, handler 는 play 끝에서 **한 번만** 실행됨 (중복 재시작 방지)
- **선언적 동작** — "config 가 바뀌면 자동으로 재시작" 을 한 곳에서 표현

## 핵심 동작

- `notify: <handler 이름>` 은 task 가 `changed` 됐을 때만 발동
- handler 는 play 의 모든 task 가 끝난 뒤 발동된 순서대로 한 번 실행
- play 중간에 즉시 실행하고 싶으면 `ansible.builtin.meta: flush_handlers`

## 실제 작업에서 같은 패턴 보기

- [`tasks/linux/nginx-healthcheck/`](../../tasks/linux/nginx-healthcheck/) — `notify: restart nginx` 로 conf 가 바뀌었을 때만 nginx 재시작
- [`tasks/linux/baseline/`](../../tasks/linux/baseline/) — chrony role 에서 설정 변경 시 `chronyd` 재시작
