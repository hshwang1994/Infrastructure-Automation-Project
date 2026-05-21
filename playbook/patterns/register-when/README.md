# patterns/register-when — 결과를 잡고 다음 task 에서 분기

task 결과를 `register:` 로 변수에 저장하고, 다음 task 의 `when:` 에서 그 변수를 보고 분기하는 패턴. **이전 단계의 결과에 따라 다음 단계가 달라져야 할 때** 거의 무조건 쓰는 흐름이다.

## 데모 시나리오

`/tmp/register-demo.txt` 가 있는지 확인 → 없으면 만들고, 있으면 안내만 → 어쨌든 내용을 읽어 출력.

처음 돌리면 1·2 task 가 trigger 되고, 두 번째 돌리면 1·2'·3·4 가 trigger 된다.

## register 가 잡는 결과 형태

`register` 된 변수는 모듈마다 다른 필드를 갖지만 공통적으로:

| 필드            | 의미                                            |
|:----------------|:------------------------------------------------|
| `.changed`      | task 가 시스템을 바꿨는지 (true / false)        |
| `.failed`       | 실패했는지                                      |
| `.rc`           | command/shell 의 return code                    |
| `.stdout`       | command/shell 의 표준출력                       |
| `.stdout_lines` | stdout 을 줄 단위 리스트로                      |
| `.stat`         | `stat` 모듈의 결과 (exists, size, mode 등)      |
| `.results`      | `loop:` 으로 돈 task 의 항목별 결과 리스트      |

## when 에서 잡은 변수 사용

```yaml
when: target_stat.stat.exists                  # bool 필드
when: contents.rc == 0                          # 숫자 비교
when: "'특정문자열' in contents.stdout"          # 문자열 포함
when: contents.stdout_lines | length > 5        # 필터 + 비교
when:
  - cond_a                                      # 리스트는 AND
  - cond_b
```

## 언제 쓰나

- **사전 상태 확인 후 분기** — 파일 / 패키지 / service 가 이미 있으면 skip
- **외부 명령 결과로 다음 동작 결정** — `curl` 응답 코드 보고 다음 action
- **idempotent 패턴** — 매번 안전하게 다시 돌릴 수 있도록 변경 여부 추적

## 실제 작업에서 같은 패턴 보기

- [`tasks/linux/pkg-update/post.yml`](../../tasks/linux/pkg-update/post.yml) — `service_facts` 결과로 sshd 상태 분기
- [`tasks/linux/disk-check/`](../../tasks/linux/disk-check/) — `command` 결과를 register 해서 debug 출력
- [`sandbox/`](../../sandbox/) `post.yml` — `stat` 결과로 파일 존재 검증
