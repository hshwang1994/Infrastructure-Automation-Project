# patterns/lookup — 컨트롤러 쪽에서 동적 값 가져오기

playbook 에 비밀번호나 토큰을 직접 박아두면 보안 문제. 또 빌드 시점에 정해지는 값 (git commit hash, 현재 시각, 환경별 설정값 …) 도 박아둘 수 없다.

`lookup` 은 ansible 을 **실행하는 컨트롤러 머신** 에서 동적으로 값을 가져오는 도구다. 환경변수, 외부 파일 내용, 명령 실행 결과 등을 변수에 잡아둘 수 있다.

> 타깃 호스트가 아니라 **컨트롤러** 에서 평가된다는 점이 핵심이다. 예: `lookup('env', 'HOME')` 은 SSH 로 접속한 타깃 서버의 HOME 이 아니라, ansible-playbook 명령을 친 사람 (또는 Jenkins agent) 의 HOME 을 가져온다.

## 자주 쓰는 lookup plugin

| plugin     | 무엇을 가져오나                                       |
|:-----------|:------------------------------------------------------|
| `env`      | 컨트롤러의 환경변수 (`HOME`, `REPO_ROOT` 등)          |
| `file`     | 같은 디렉토리(또는 `files/`) 의 텍스트 파일 내용      |
| `pipe`     | 컨트롤러에서 명령 실행 후 stdout                      |
| `template` | Jinja2 식을 즉석에서 렌더한 결과                      |

이 외에 `password` (비번 생성·캐시), `vars` (다른 변수 lookup), `csvfile` (CSV 조회) 등이 있다.

## 동작 흐름

```yaml
vars:
  api_token: "{{ lookup('env', 'API_TOKEN') }}"
  ssh_key:   "{{ lookup('file', '/home/jenkins/.ssh/id_rsa.pub') }}"
  build_id:  "{{ lookup('pipe', 'git rev-parse --short HEAD') }}"
```

위 세 변수는 playbook 실행 시점에 컨트롤러에서 자동으로 채워진다. 타깃 호스트에서는 이 변수들을 그냥 값으로 사용한다.

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

화면에:
- 컨트롤러의 `HOME` / `REPO_ROOT` (env)
- 같은 디렉토리 `hello.txt` 의 내용 (file)
- 컨트롤러에서 `whoami` 친 결과 (pipe)

이 출력된다. 환경변수를 바꾸거나 `hello.txt` 를 수정하고 다시 돌려보면 결과가 즉시 반영된다.

## 알아두면 좋은 것

- 결과가 비어있을 때를 위해 `| default('값', true)` 를 같이 쓰는 게 안전 (`true` 두 번째 인자가 "빈 문자열도 default 발동" 옵션)
- lookup 은 playbook 평가 시점에 실행되므로, `--check` (dry-run) 모드여도 lookup 자체는 돈다 — 비밀 값 조회를 신중히

## 실제 작업에서 어디 쓰이나

모든 playbook 의 `vars_files:` 가 `"{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"` 형태 — 환경변수 lookup 으로 vault 파일 경로를 동적으로 결정한다. Jenkins 빌드마다 workspace 경로가 달라지기 때문.
