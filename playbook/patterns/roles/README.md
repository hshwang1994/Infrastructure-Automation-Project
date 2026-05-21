# patterns/roles — task 묶음을 재사용 가능한 단위로 분리

같은 작업을 여러 playbook 에서 또 쓸 일이 자주 생긴다 (예: chrony 설치 + 설정 + 재시작 묶음, nginx 베이스 셋업 묶음). 그때마다 task 코드를 복붙하면:

- 한 곳을 고치면 다른 곳도 다 고쳐야 한다 (빼먹기 쉬움)
- playbook 길이가 길어져 한눈에 안 들어온다

Ansible 의 **role** 은 task 묶음을 "재사용 가능한 모듈" 처럼 분리해두는 표준 디렉토리 구조다. 프로그래밍 언어의 함수·라이브러리 비슷한 역할.

## 구조

```
roles/
├── site.yml                           짧음 — roles 리스트만 선언
└── roles/
    └── welcome/                       role 하나
        ├── tasks/main.yml             실제 task (이게 본체)
        ├── defaults/main.yml          변수 기본값 (호출하는 쪽이 덮어쓸 수 있음)
        └── handlers/main.yml          notify 로 호출되는 handler
```

표준 디렉토리가 더 있다 — `templates/`, `files/`, `vars/`, `meta/` 등. 필요할 때 추가하면 된다.

## 동작 흐름

1. `site.yml` 이 `roles: [welcome]` 한 줄만 적음
2. Ansible 이 `roles/welcome/` 디렉토리를 자동 발견
3. `tasks/main.yml` 의 task 들이 실행됨
4. `defaults/main.yml` 의 기본값이 변수로 들어옴 — 호출하는 쪽에서 일부만 덮어쓸 수 있음
5. `handlers/main.yml` 의 handler 도 묶여 있어서 `notify` 가 자연스럽게 동작

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

기본 메시지 "hello from welcome role" 이 출력된다. 다른 값으로 바꿔보고 싶으면:

```bash
ansible-playbook -i 인벤토리 site.yml -e "welcome_message=안녕"
```

`defaults/main.yml` 의 값이 override 되어 "안녕" 으로 출력.

## role 을 쓰면 좋은 점

- **재사용** — 다른 playbook 에서 같은 role 을 그냥 가져다 씀
- **변수 override** — 환경별로 일부 값만 바꿔서 호출 가능
- **표준 구조** — 누가 봐도 어디에 task / handler / template 이 있는지 즉시 파악
- **dependencies** — `meta/main.yml` 에 다른 role 의존 선언 가능

## 실제 작업에서 어디 쓰이나

`tasks/linux/baseline/` — chrony role + motd role 두 개를 묶어 baseline 구성. baseline 디렉토리의 site.yml 이 `roles: [chrony, motd]` 한 줄로 끝난다.
