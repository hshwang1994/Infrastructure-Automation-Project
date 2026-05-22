# sandbox/user08 — 연습용 슬롯

두 stage 가 같은 슬롯 안에서 **builtin** 과 **shell** 두 가지 ansible 사용 방식을 비교한다.

| 파일       | stage   | 모듈                       | 무엇을 하는가                              |
| :--------- | :------ | :------------------------- | :----------------------------------------- |
| `main.yml` | Builtin | `ansible.builtin.copy`     | `/tmp/practice.txt` 작성 (고수준 모듈)     |
| `post.yml` | Shell   | `ansible.builtin.shell`    | 같은 파일을 `test -f` + `cat` 으로 검증    |

같은 결과 (`/tmp/practice.txt` 의 존재·내용 확인) 를 builtin 모듈 vs 쉘 명령 두 방식으로 처리하는 흐름을 보면, 어느 쪽이 멱등성·로그·에러처리 면에서 깔끔한지 감 잡을 수 있다.

전체 안내·다른 슬롯 정보·Jenkins 등록 절차는 [`../README.md`](../README.md).

Jenkins Script Path: `Day2_Guide/playbook/sandbox/user08/Jenkinsfile`

기본 파라미터(`loc=ich`, `target_type=linux`, `inventory_json=[{"hostname":"linux-dev-01","service_ip":"10.100.64.169"}]`) 로 바로 Build 가능.
