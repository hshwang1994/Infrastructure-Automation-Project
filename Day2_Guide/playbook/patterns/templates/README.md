# patterns/templates — 호스트별로 다른 설정 파일을 동적으로 만들기

`template:` 모듈은 Jinja2 템플릿 파일(`*.j2`)에 변수를 채워 설정 파일을 만든다.
같은 틀로 호스트마다 다른 값을 가진 파일을 일관되게 생성할 수 있다.

## 왜 필요한가

운영 자동화에서는 같은 형식이지만 호스트마다 값이 달라야 하는 설정 파일이 많다.
예를 들어 nginx 의 `server_name`, chrony 의 NTP 서버 목록, `motd` 의 환영 메시지가 그렇다.
호스트별로 파일을 수작업으로 만들면 누락이 생기고, 한 항목만 바뀌어도 손댈 곳이 늘어난다.
`template` 은 "틀 한 장 + 변수" 로 분리해서, 변수 값만 바꾸면 같은 모양의 파일이 호스트마다 자동으로 만들어진다.
Jenkins shell 의 `sed` 치환이나 `cat <<EOF` heredoc 으로 하던 일을 한 task 로 깔끔하게 정리한다고 보면 된다.

## 먼저 알아둘 말

- `Jinja2` — 변수, 반복, 조건, 필터를 포함하는 Python 계열 템플릿 문법이다.
- `templates/` 디렉토리 — `template:` 모듈은 같은 폴더 안의 `templates/` 에서 `.j2` 파일을 자동으로 찾는다.
- `gather_facts: true` — 템플릿에서 `ansible_date_time` 같은 fact 를 쓰려면 fact 수집이 켜져 있어야 한다.

## 최소 예제

`service_name` 변수를 받아 conf 파일을 만든다.

```yaml
- name: 템플릿 렌더링해서 설정 파일 생성
  ansible.builtin.template:
    src:  demo.conf.j2
    dest: /tmp/template-demo.conf
    mode: '0644'
```

`templates/demo.conf.j2` 안에서는 `{{ service_name }}` 같은 표현이 실제 변수 값으로 치환된다.
playbook 의 `vars:` 에 정의된 값과 `ansible_facts` 의 값을 함께 쓸 수 있다.

## 전체 예제 흐름

`site.yml` 은 변수 정의 → 템플릿 렌더링 → 결과 다시 읽기 → 화면 출력 흐름이다.

```yaml
- name: templates 데모
  hosts: all
  gather_facts: true

  vars:
    service_name: demo-api
    service_port: 8080
    enabled_features: [cache, metrics, tracing]

  tasks:
    - name: 템플릿 렌더링
      ansible.builtin.template:
        src:  demo.conf.j2
        dest: /tmp/template-demo.conf
        mode: '0644'

    - name: 생성된 내용 다시 읽기
      ansible.builtin.slurp:
        src: /tmp/template-demo.conf
      register: out

    - name: 결과 출력
      ansible.builtin.debug:
        msg: "{{ (out.content | b64decode) | trim }}"
```

`templates/demo.conf.j2` 안에는 다음과 같은 문법이 들어있다.

```jinja
service_name = {{ service_name }}
listen_port  = {{ service_port }}
host         = {{ inventory_hostname }}

{% for f in enabled_features %}
feature.{{ f }} = true
{% endfor %}

owner      = {{ owner | default('infra') }}
service_id = {{ service_name | upper }}
```

실행 순서는 다음과 같다.

1. `gather_facts` 로 OS, 시간 같은 기본 정보를 수집한다.
2. `template` 모듈이 `demo.conf.j2` 를 읽어 변수와 fact 를 채운다.
3. 렌더링된 결과를 `/tmp/template-demo.conf` 로 배치한다.
4. `slurp` 가 그 파일 내용을 base64 로 가져온다.
5. `debug` 가 그 내용을 디코딩해 화면에 보여준다.

## 직접 돌려보기

### 실행 전 확인

- 대상 서버: Linux (RHEL 9 계열)
- Ansible: 2.15 이상
- 동적 인벤토리: `inventory/my_inventory.sh`
- 환경변수:
  ```bash
  export TARGET_TYPE=linux
  export INVENTORY_JSON='[{"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"}]'
  ```

```bash
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/templates/site.yml
```

### 기대 결과 (첫 실행)

```text
TASK [템플릿 렌더링해서 설정 파일 생성] *****************
changed: [rhel9-dev-01]

TASK [결과 출력] ************************************
ok: [rhel9-dev-01] => {
    "msg": "# demo-api configuration
# generated for rhel9-dev-01 at 2026-...
service_name = demo-api
listen_port  = 8080
host         = rhel9-dev-01
feature.cache   = true
feature.metrics = true
feature.tracing = true
owner      = infra
service_id = DEMO-API"
}
```

## 두 번째 실행에서 볼 것

같은 변수로 다시 돌리면 파일 내용이 동일하므로 `template` task 가 `ok` 로 끝난다.
`service_port` 값이나 `enabled_features` 목록을 바꿔서 다시 돌리면 `changed=1` 으로 다시 잡힌다.
"입력 변수가 같으면 결과 파일도 같다" 는 멱등성이 이 패턴의 핵심이고, 두 번째 실행에서 가장 잘 보인다.

```text
TASK [템플릿 렌더링해서 설정 파일 생성] *****************
ok: [rhel9-dev-01]
```

## 자주 쓰는 모양 (Jinja2 문법)

| 상황 | 예시 |
|---|---|
| 변수 치환 | `{{ service_name }}` |
| 기본값 | `{{ owner \| default('infra') }}` |
| 리스트 반복 | `{% for f in features %}feature.{{ f }} = true{% endfor %}` |
| 조건 분기 | `{% if env == 'prod' %}log_level = info{% endif %}` |
| 대소문자 변환 | `{{ name \| upper }}`, `{{ name \| lower }}` |
| JSON 직렬화 | `{{ obj \| to_json }}`, `{{ obj \| to_nice_json }}` |
| host fact 사용 | `{{ ansible_facts.distribution }}`, `{{ ansible_date_time.iso8601 }}` |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/baseline/` — `motd.j2` 가 호스트별 로그인 배너를 만든다. hostname 과 날짜가 자동으로 들어간다.
- `patterns/handlers/` — 템플릿 결과가 바뀐 호스트에서만 서비스를 재시작하도록 `notify` 와 같이 쓰는 흐름.
- `patterns/loops/` — 변수에 들어있는 리스트를 템플릿 안의 `{% for %}` 로 풀어내는 흐름과 짝이 된다.
