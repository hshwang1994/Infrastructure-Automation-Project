# patterns/import-include — task 파일을 여러 개로 쪼개기

playbook 이 task 100 줄을 넘어가면 한눈에 안 들어온다. task 를 별도 yml 파일로 빼내서 메인에서 불러오면 깔끔해진다.

부르는 방법이 두 가지다 — `import_tasks` 와 `include_tasks`. 거의 똑같아 보이지만 한 가지 결정적 차이가 있다:

- **`import_tasks` (정적)** — playbook 을 **읽는 순간** 합쳐짐. 컴파일 시 `#include` 처럼.
- **`include_tasks` (동적)** — **실행 도중에** 평가됨. 런타임에 결정되는 함수 호출처럼.

이 차이가 "loop 와 같이 쓸 수 있나" 같은 실용적 차이로 이어진다.

## 구조

```
import-include/
├── site.yml         메인 play (두 가지 방식 다 호출)
├── imported.yml     import_tasks 로 가져올 task 모음
└── included.yml     include_tasks 로 loop 와 함께 부를 task 모음
```

## 동작 흐름

site.yml 안:

```yaml
tasks:
  - name: 1) 정적 import — playbook 시작 시 합쳐짐
    ansible.builtin.import_tasks: imported.yml

  - name: 2) 동적 include — env 마다 한 번씩
    ansible.builtin.include_tasks: included.yml
    loop:
      - dev
      - prod
    loop_control:
      loop_var: env_name
```

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

`imported.yml` 의 task 들이 먼저 실행 (uptime 표시), 그 다음 `included.yml` 이 `env_name=dev`, `env_name=prod` 두 번 실행 (각각 `/tmp/include-demo-dev.conf`, `/tmp/include-demo-prod.conf` 생성).

## import vs include — 핵심 비교

| 항목                | `import_tasks` (정적)                | `include_tasks` (동적)                  |
|:--------------------|:-------------------------------------|:----------------------------------------|
| 평가 시점           | playbook 파싱 시                     | 실행 도중                               |
| `loop:` 와 같이     | 불가                                 | **가능**                                |
| `when:` 동작        | 안쪽 모든 task 에 적용               | include 자체에 적용 (false 면 통째로 skip) |
| 변수로 파일명       | 제한적                               | 자유롭게 (`{{ var }}.yml`)              |
| `--list-tasks` 출력 | 모든 task 보임                       | 포함 task 안 보임                       |

## 선택 기준 한 줄

- 단순히 코드 나누고 재사용만 → `import_tasks`
- loop 같이 쓰거나 변수로 파일명 지정 → `include_tasks`

## 실제 작업에서 어디 쓰이나

role 의 `tasks/main.yml` 은 자동으로 import 됨 (예: `tasks/linux/baseline/`). role 안 task 는 정적 import 컨벤션이다.
