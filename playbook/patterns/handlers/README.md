# patterns/handlers — 설정이 바뀌었을 때만 서비스 재시작

서비스 설정 파일(nginx.conf, sshd_config 같은 거)을 고치면 그 서비스를 다시 띄워야 새 설정이 적용된다. 그런데 매번 무조건 재시작하면:

- 사용자 입장에서 잠깐 서비스가 끊긴다
- 재시작 후에 잘 떠 있는지 확인해야 한다
- 설정 파일 5개를 한 번에 손봤다고 재시작을 5번? 비효율

그래서 "**진짜로 설정이 바뀌었을 때만** 재시작" 이 필요하다. Ansible 의 handler 가 정확히 이걸 해준다.

## 동작 흐름

1. 설정 파일을 만지는 task 옆에 `notify: <handler 이름>` 표시
2. 그 task 가 **실제로 파일을 바꿨다면** (Ansible 이 `changed` 로 인식) → notify 가 켜짐
3. 켜진 handler 는 playbook 의 모든 task 가 끝난 뒤 **딱 한 번** 실행

같은 service 를 5번 notify 해도 handler 는 마지막에 한 번뿐. Ansible 이 알아서 묶어준다.

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

세 번 돌려보면 차이가 보인다:

| 회차 | 무슨 일이 일어나나                                |
|:---:|:--------------------------------------------------|
| 1   | 파일이 새로 생김 → "재시작했다" 메시지 출력        |
| 2   | 내용 동일 → handler 안 돌고 넘어감                  |
| 3   | `vars: config_body` 값을 바꾸고 돌리면 → 다시 실행 |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/nginx-healthcheck/` — nginx 설정 conf 바뀐 경우에만 nginx 재시작
- `tasks/linux/baseline/` — chrony 설정 바뀐 경우에만 chronyd 재시작
