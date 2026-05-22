# sandbox/user04 — 연습용 슬롯

세 stage 가 같은 슬롯 안에서 **builtin** / **shell** / **Jenkins → ansible 변수 전달** 세 가지 ansible 사용 방식을 보여준다.

| 파일       | stage   | 모듈                       | 무엇을 하는가                              |
| :--------- | :------ | :------------------------- | :----------------------------------------- |
| `main.yml`      | Builtin   | `ansible.builtin.copy`     | `/tmp/practice.txt` 작성 (고수준 모듈)                     |
| `post.yml`      | Shell     | `ansible.builtin.shell`    | 같은 파일을 `test -f` + `cat` 으로 검증                    |
| `extravars.yml` | ExtraVars | `ansible.builtin.debug`    | Jenkinsfile `greeting` 파라미터를 extraVars 로 받아 출력   |

같은 결과 (`/tmp/practice.txt` 의 존재·내용 확인) 를 builtin 모듈 vs 쉘 명령 두 방식으로 처리하는 흐름에서 멱등성·로그·에러처리 차이를, `extravars.yml` 에서는 Jenkins 파라미터 (`greeting`) 가 `extraVars` Map 으로 ansible 안 변수가 되는 표준 패턴을 볼 수 있다.

전체 안내·다른 슬롯 정보·Jenkins 등록 절차는 [`../README.md`](../README.md).

Jenkins Script Path: `Day2_Guide/playbook/sandbox/user04/Jenkinsfile`

기본 파라미터(`loc=ich`, `target_type=linux`, `inventory_json=[{"hostname":"linux-dev-01","service_ip":"10.100.64.169"}]`) 로 바로 Build 가능.
