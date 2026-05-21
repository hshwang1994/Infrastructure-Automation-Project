# patterns/templates — Jinja2 template 모듈

`ansible.builtin.template` 으로 Jinja2 템플릿을 렌더링해서 타겟에 파일을 배치. 변수 치환 · 반복 · 조건 · 필터 등을 활용할 수 있다.

## 구조

```
templates/
├── site.yml
└── templates/
    └── demo.conf.j2
```

`template:` 모듈은 `templates/` 디렉토리 안에서 `.j2` 파일을 자동으로 찾는다.

## 데모 시나리오

`service_name`, `service_port`, `enabled_features` 같은 변수를 넘기고, `demo.conf.j2` 가:
- 단순 치환 (`{{ service_name }}`)
- 반복 (`{% for f in enabled_features %}`)
- 필터 (`{{ service_name | upper }}`, `{{ owner | default('infra') }}`)

를 한 파일에서 보여준다. 결과는 `/tmp/template-demo.conf`.

## 자주 쓰는 Jinja2 패턴

- **치환**: `{{ var }}`
- **default 값**: `{{ var | default('fallback') }}`
- **반복**: `{% for x in list %} ... {% endfor %}`
- **조건**: `{% if env == 'prod' %} ... {% endif %}`
- **JSON 변환**: `{{ dict_var | to_json }}` / `to_nice_json`
- **공백 제어**: `{%- for x in list %}` 로 앞뒤 공백 제거

## 언제 쓰나

- **service config 파일 생성** — nginx, sshd, chrony, prometheus 등 모든 config
- **호스트별 다른 값을 넣어야 할 때** — hostname, IP, role 같은 값을 동적으로
- **여러 환경에서 같은 골격, 다른 값** — dev / staging / prod 별 config

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/baseline/`](../../tasks/linux/baseline/) — motd role 이 `templates/motd.j2` 로 호스트별 로그인 배너 생성.
