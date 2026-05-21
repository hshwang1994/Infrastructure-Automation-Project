# patterns/templates — 설정 파일을 호스트별로 동적 생성

nginx 설정, chrony 설정, sshd 설정 같은 config 파일을 만들 때 호스트마다 값이 달라야 한다 (hostname, IP, 활성화할 기능 목록 등). 매번 호스트별로 다른 파일을 손으로 만들면 사고가 나기 쉽다.

Jinja2 **템플릿** 은 "틀 + 값" 으로 분리해서, 같은 틀에 호스트별 값만 채워 동적으로 만들어준다. Python 의 f-string, JavaScript 의 template literal 과 같은 개념을 파일 단위로 한 거라고 보면 된다.

## 구조

```
templates/
├── site.yml                       playbook (틀에 채울 값 정의)
└── templates/
    └── demo.conf.j2               .j2 = Jinja2 템플릿 파일
```

`template:` 모듈은 `templates/` 디렉토리 안에서 `.j2` 파일을 자동으로 찾는다.

## 동작 흐름

1. `vars:` 에 값들을 정의 (`service_name`, `service_port`, `enabled_features` …)
2. `template:` 모듈이 `templates/demo.conf.j2` 를 읽어 변수를 채워 렌더링
3. 결과를 타깃의 `/tmp/template-demo.conf` 에 배치
4. 배치된 파일을 다시 읽어서 화면에 출력 (결과 확인용)

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

마지막에 출력되는 conf 파일 안에 `service_name`, `inventory_hostname`, 시각, 기능 목록 등이 채워져 있는 게 보인다. `vars` 값을 바꾸고 다시 돌려보면 결과가 달라진다.

## Jinja2 의 흔한 문법

| 쓰임             | 예시                                                            |
|:-----------------|:----------------------------------------------------------------|
| 변수 치환        | `{{ var }}`                                                     |
| default 값       | `{{ var \| default('infra') }}` (변수가 없으면 'infra' 사용)    |
| 반복             | `{% for x in list %} ... {% endfor %}`                          |
| 조건             | `{% if env == 'prod' %} ... {% endif %}`                        |
| 대문자 변환      | `{{ name \| upper }}`                                           |
| JSON 출력        | `{{ dict_var \| to_json }}` / `to_nice_json`                    |

## 실제 작업에서 어디 쓰이나

`tasks/linux/baseline/` 의 motd role — `templates/motd.j2` 가 호스트별 로그인 배너를 만든다. hostname 자동 삽입.
