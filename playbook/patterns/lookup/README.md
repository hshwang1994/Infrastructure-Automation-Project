# patterns/lookup — 컨트롤러에서 값 동적 조회

`{{ lookup('<plugin>', '<인자>') }}` 으로 **ansible 컨트롤러 쪽에서** 환경변수 · 파일 내용 · 명령 결과 등 동적 값을 가져온다. 타겟 호스트가 아니라 **playbook 을 실행하는 머신** 에서 평가된다는 점이 핵심.

## 데모 시나리오

| lookup plugin  | 무엇을 가져오나                                         |
|:---------------|:--------------------------------------------------------|
| `env`          | 컨트롤러의 환경변수 (HOME, REPO_ROOT 등)                |
| `file`         | 같은 디렉토리 (또는 `files/`) 의 텍스트 파일 내용       |
| `pipe`         | 컨트롤러에서 명령 실행 후 stdout                        |
| `template`     | Jinja2 식을 즉석에서 렌더한 결과                        |

이 외에 자주 쓰는 것: `password` (비번 생성·캐시), `vars` (다른 변수 lookup), `dict` / `subelements` (자료구조 변환), `csvfile` (CSV 조회).

## 흔한 패턴

```yaml
vars:
  api_token: "{{ lookup('env', 'API_TOKEN') }}"
  ssh_key:   "{{ lookup('file', '/home/jenkins/.ssh/id_rsa.pub') }}"
  build_id:  "{{ lookup('pipe', 'git rev-parse --short HEAD') }}"
```

- **`| default('fallback', true)`** — lookup 결과가 비어있으면 fallback 사용 (`true` 두 번째 인자 중요)
- lookup 은 **playbook parse / 평가 시점** 에 실행되므로, 비밀 값을 그대로 변수에 넣으면 `--check` 모드에서도 lookup 이 실행될 수 있음

## 언제 쓰나

- **환경별 비밀번호·토큰을 환경변수로 주입** — CI 시스템에서 흔함
- **외부 파일에 적힌 설정값** — `motd` 텍스트, key 파일 등
- **컨트롤러 측 명령 결과 사용** — git commit hash, hostname, 빌드 시각

## 실제 작업에서 같은 패턴 보기

모든 task 의 playbook `vars_files:` — `"{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"` 형태로 환경변수 lookup 으로 vault 경로를 동적 결정.
