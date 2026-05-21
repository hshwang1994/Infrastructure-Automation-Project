# patterns/import-include — task 파일 분리·재사용

`import_tasks` 와 `include_tasks` 둘 다 task 모음을 별도 파일로 분리하는 데 쓰지만, **평가 시점**과 **동적 기능** 에서 명확한 차이가 있다.

## 구조

```
import-include/
├── site.yml       메인 play
├── imported.yml   import_tasks 로 가져올 정적 task 모음
└── included.yml   include_tasks 로 loop 와 함께 부를 동적 task 모음
```

## 데모 시나리오

1. `import_tasks: imported.yml` — uptime 받아 debug 로 출력 (모든 호스트에서 한 번씩)
2. `include_tasks: included.yml` 을 `loop: [dev, prod]` 와 같이 — env 별로 `/tmp/include-demo-{env}.conf` 생성

## import vs include — 결정적 차이

| 항목                | `import_tasks` (정적)                            | `include_tasks` (동적)                         |
|:--------------------|:-------------------------------------------------|:-----------------------------------------------|
| 평가 시점           | playbook 파싱 시 합쳐짐                          | task 실행 시점에 평가                          |
| `loop:` 와 결합     | 불가                                             | 가능                                           |
| `when:` 동작        | 안쪽 모든 task 에 일괄 적용                      | 포함 자체에 적용 — 조건 false 면 파일 자체 skip |
| 변수로 파일명 지정  | 제한적 (파싱 시점에 알 수 있는 값만)             | 자유롭게 가능 (`{{ var }}.yml`)                |
| `--list-tasks` 출력 | 모든 task 보임                                   | 포함 task 안 보임                              |

## 언제 어느 것

- **`import_tasks`**: 단순 분리 · 재사용. role 의 `tasks/main.yml` 구조와 잘 맞음
- **`include_tasks`**: 동적 요소 필요 — loop, 변수로 파일명, 조건부 전체 skip

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/baseline/`](../../tasks/linux/baseline/) 의 role 구조 — `roles/{name}/tasks/main.yml` 이 자동으로 `import` 됨 (role 의 task 는 정적 import 컨벤션).
