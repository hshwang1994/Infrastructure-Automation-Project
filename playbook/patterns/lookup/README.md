# patterns/lookup — 컨트롤러 쪽에서 동적으로 값 가져오기

`lookup` 은 ansible 을 실행하는 컨트롤러 머신에서 동적으로 값을 가져오는 도구다.
환경변수, 외부 파일 내용, 명령 실행 결과 같은 값을 playbook 안 변수에 그대로 잡아둘 수 있다.

## 왜 필요한가

자동화 작업을 돌릴 때, playbook 안에 비밀번호나 토큰을 직접 박아두면 보안 문제로 이어진다.
또 빌드 시점에 정해지는 값(현재 시각, git commit hash, 환경별 vault 경로)은 작성 시점에 알 수 없어서 박아둘 수도 없다.
이런 값은 ansible-playbook 명령을 친 컨트롤러 쪽에서 그때그때 읽어와야 한다.
`lookup` 은 그 자리에서 값을 꺼내 변수에 채우는 표준 방식이다.
Jenkins shell 에서 `KEY=$(cat /secret/path)` 로 잡던 패턴이 그대로 옮겨온다고 보면 된다.

> 타깃 호스트가 아니라 컨트롤러에서 평가된다는 점이 핵심이다.
> 예: `lookup('env', 'HOME')` 은 SSH 로 접속한 타깃의 HOME 이 아니라, `ansible-playbook` 명령을 친 사용자(또는 Jenkins agent)의 HOME 을 가져온다.

## 먼저 알아둘 말

- `lookup('plugin', '인자')` — 컨트롤러에서 plugin 이 정의된 방식으로 값을 가져온다.
- `env` plugin — 컨트롤러 프로세스의 환경변수를 읽는다.
- `file` plugin — 같은 디렉토리(또는 role 의 `files/`)에서 텍스트 파일 내용을 읽는다.
- `pipe` plugin — 컨트롤러에서 명령을 실행해 stdout 을 가져온다.

## 최소 예제

세 가지 lookup 결과를 출력한다.

```yaml
- name: env lookup — 컨트롤러의 환경변수
  ansible.builtin.debug:
    msg: "HOME = {{ lookup('env', 'HOME') }}"

- name: file lookup — 같은 디렉토리 파일
  ansible.builtin.debug:
    msg: "hello.txt = {{ lookup('file', 'hello.txt') | trim }}"

- name: pipe lookup — 컨트롤러에서 명령 실행
  ansible.builtin.debug:
    msg: "whoami = {{ lookup('pipe', 'whoami') }}"
```

세 task 모두 컨트롤러에서 값이 결정된다.
SSH 로 접속한 타깃 호스트의 상태와는 무관하다.

## 전체 예제 흐름

`site.yml` 은 `vars:` 에서 lookup 값을 잡고, task 들에서 그 변수를 다시 출력한다.

```yaml
vars:
  home_dir:  "{{ lookup('env', 'HOME') }}"
  repo_root: "{{ lookup('env', 'REPO_ROOT') | default('(REPO_ROOT 미설정)', true) }}"

tasks:
  - name: env lookup
    ansible.builtin.debug:
      msg: "HOME = {{ home_dir }} / REPO_ROOT = {{ repo_root }}"

  - name: file lookup
    ansible.builtin.debug:
      msg: "hello.txt 내용 = {{ lookup('file', 'hello.txt') | trim }}"

  - name: pipe lookup
    ansible.builtin.debug:
      msg: "컨트롤러의 현재 사용자 = {{ lookup('pipe', 'whoami') }}"
```

실행 순서는 다음과 같다.

1. play 시작 전, `vars:` 안의 lookup 들이 컨트롤러에서 평가된다.
2. `home_dir`, `repo_root` 에 컨트롤러 환경변수 값이 들어간다.
3. 첫 번째 task 가 두 변수 값을 출력한다.
4. 두 번째 task 가 `hello.txt` 파일 내용을 출력한다.
5. 세 번째 task 가 컨트롤러에서 `whoami` 를 실행한 결과를 출력한다.

`default('값', true)` 의 두 번째 인자 `true` 는 "빈 문자열도 default 로 대체" 라는 옵션이다.

## 직접 돌려보기

### 실행 전 확인

- 대상 서버: Linux (RHEL 9 계열) — 단, lookup 자체는 컨트롤러에서 평가됨
- Ansible: 2.15 이상
- 동적 인벤토리: `inventory/my_inventory.sh`
- 환경변수:
  ```bash
  export TARGET_TYPE=linux
  export INVENTORY_JSON='[{"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"}]'
  export REPO_ROOT="$(pwd)"
  ```

```bash
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/lookup/site.yml
```

### 기대 결과

```text
TASK [env lookup] ***************************************
ok: [rhel9-dev-01] => {
    "msg": "HOME = /home/jenkins / REPO_ROOT = /var/lib/jenkins/workspace/..."
}

TASK [file lookup] **************************************
ok: [rhel9-dev-01] => {
    "msg": "hello.txt 내용 = hello from lookup demo"
}

TASK [pipe lookup] **************************************
ok: [rhel9-dev-01] => {
    "msg": "컨트롤러의 현재 사용자 = jenkins"
}
```

`REPO_ROOT` 를 다른 값으로 export 한 뒤 다시 돌리면 출력이 바뀐다.
`hello.txt` 파일 내용을 바꾼 뒤 다시 돌려도 결과가 즉시 반영된다.

## 자주 쓰는 모양 (lookup plugin 별)

| plugin | 무엇을 가져오나 | 예시 |
|---|---|---|
| `env` | 컨트롤러 환경변수 | `lookup('env', 'REPO_ROOT')` |
| `file` | 텍스트 파일 내용 | `lookup('file', 'key.pub')` |
| `pipe` | 컨트롤러 명령 stdout | `lookup('pipe', 'git rev-parse --short HEAD')` |
| `password` | 비밀번호 생성·캐시 | `lookup('password', 'credentials/db.txt length=16')` |
| `vars` | 다른 변수 동적 조회 | `lookup('vars', some_var_name)` |
| `csvfile` | CSV 한 셀 조회 | `lookup('csvfile', 'host file=hosts.csv col=1')` |
| `template` | Jinja2 문자열 렌더 | `lookup('template', 'snippet.j2')` |

## 막힐 때 확인

> 증상: `lookup('env', 'XXX')` 가 빈 문자열을 돌려준다.
>
> 확인할 것:
> - 환경변수가 `ansible-playbook` 을 실행한 셸에 정말 export 되어 있는지 본다.
> - `export REPO_ROOT=$(pwd)` 같은 식으로 같은 셸에서 직접 설정한 뒤 다시 돌린다.
> - 빈 문자열을 대비해 `| default('값', true)` 를 같이 쓰면 안전하다.

> 증상: `--check` (dry-run) 모드인데도 외부 명령이 실제로 도는 것 같다.
>
> 확인할 것:
> - `lookup` 은 playbook 평가 시점에 컨트롤러에서 실행되므로, check mode 와 무관하게 한 번 돈다.
> - 비밀 값이나 부수효과가 있는 명령을 `pipe` 로 호출할 때는 그 점을 의식하고 쓴다.

## 실제 작업에서 어디 쓰이나

- 이 리포의 거의 모든 playbook 이 `vars_files: "{{ lookup('env', 'REPO_ROOT') }}/vault/linux.yml"` 형태를 사용한다. Jenkins workspace 경로가 빌드마다 달라지기 때문에 환경변수 lookup 으로 vault 위치를 동적으로 결정한다.
- `patterns/templates/` — 템플릿 안에서도 `lookup` 결과를 변수로 받아 그대로 쓸 수 있다.
- `patterns/register-when/` — lookup 으로 받은 값을 다시 `when:` 조건으로 분기하는 흐름.
