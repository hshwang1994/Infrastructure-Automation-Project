# patterns/tags — 같은 playbook 에서 일부 단계만 골라 실행하기

`tags` 는 task 에 라벨을 붙여, 같은 playbook 안에서 일부 단계만 골라 실행할 수 있게 한다.
설치만 / 설정만 / 검증만 따로 돌리는 식의 분할 실행이 가능해진다.

## 왜 필요한가

배포 작업은 보통 "설치 → 설정 → 검증" 같은 단계로 나뉜다.
매번 전부 다 돌리면 시간이 오래 걸리고, 단계별로 사람이 중간에 승인해야 할 때 흐름이 끊긴다.
설정만 빠르게 다시 적용하거나, 배포 후 검증만 돌리고 싶은 경우도 자주 생긴다.
`tags` 는 한 playbook 안에서 단계마다 라벨을 붙여두고, 호출 시 `--tags` 로 그 라벨만 돌리게 만든다.
Jenkinsfile 의 stage 별 분리와 Ansible 의 단계 분리를 자연스럽게 이어주는 장치다.

## 먼저 알아둘 말

- `tags` — task 에 붙이는 문자열 라벨이다. 여러 task 가 같은 tag 를 공유할 수 있다.
- `--tags` — 그 라벨이 붙은 task 만 실행한다. 여러 개 지정 가능하다.
- `--skip-tags` — 그 라벨을 제외하고 나머지 task 만 실행한다.
- `always` 와 `never` — 특별한 예약 tag 다. `always` 가 붙은 task 는 `--tags` 와 무관하게 거의 항상 실행된다.

## 최소 예제

`install` / `configure` / `verify` 세 단계 task 에 각각 tag 를 붙인다.

```yaml
- name: nginx 설치
  ansible.builtin.dnf:
    name: nginx
    state: present
  tags: install

- name: 설정 배치
  ansible.builtin.copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
  tags: configure

- name: 응답 확인
  ansible.builtin.uri:
    url: http://localhost/healthz
  tags: verify
```

`--tags install` 만 주면 첫 task 만 실행되고, 나머지는 `skipping` 으로 넘어간다.

## 전체 예제 흐름

`site.yml` 은 `/tmp/tagdemo/` 디렉토리에 세 단계 task 를 담아 둔다.

```yaml
tasks:
  - name: 작업 디렉토리 준비
    ansible.builtin.file:
      path: /tmp/tagdemo
      state: directory
    tags: install

  - name: 설정 파일 배치
    ansible.builtin.copy:
      content: "key=value\n"
      dest: /tmp/tagdemo/app.conf
    tags: configure

  - name: 설정 파일 존재 확인
    ansible.builtin.stat:
      path: /tmp/tagdemo/app.conf
    register: conf
    tags: verify

  - name: 결과 출력
    ansible.builtin.debug:
      msg: "app.conf exists={{ conf.stat.exists }}"
    tags: verify
```

실행 순서는 다음과 같다.

1. `--tags` 가 없으면 4개 task 가 모두 순서대로 실행된다.
2. `--tags install` 이면 디렉토리 생성만 실행되고 나머지는 `skipping` 으로 넘어간다.
3. `--tags configure` 면 설정 파일 배치만 실행된다.
4. `--tags verify` 면 `stat` 과 마지막 `debug` 두 task 가 실행된다.
5. `--skip-tags verify` 면 verify 두 task 만 빠지고 나머지는 다 실행된다.

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

같은 playbook 을 세 가지 방식으로 돌려보면 tag 의 효과가 한눈에 보인다.

```bash
# 전체 실행
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/tags/site.yml

# verify 만 실행 (앞 단계가 이미 끝났을 때 검증만 다시)
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/tags/site.yml --tags verify

# configure 만 재적용
ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/tags/site.yml --tags configure
```

### 기대 결과 (`--tags verify`)

```text
TASK [작업 디렉토리 준비] *****************************
skipping: [rhel9-dev-01]

TASK [설정 파일 배치] *********************************
skipping: [rhel9-dev-01]

TASK [설정 파일 존재 확인] ****************************
ok: [rhel9-dev-01]

TASK [결과 출력] ************************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: app.conf exists=True"
}

PLAY RECAP **********************************************
rhel9-dev-01 : ok=2 changed=0 skipped=2
```

verify tag 가 붙은 두 task 만 실행되고 나머지는 `skipping` 으로 넘어간다.

## Jenkinsfile 다단계와 묶는 방식

Jenkinsfile 에서 stage 마다 같은 site.yml 을 다른 tag 로 호출하면, 단계 사이에 사람이 승인하거나 검토 단계를 끼울 수 있다.

```groovy
stage('install')   { sh "ansible-playbook ... --tags install"   }
stage('approval')  { input message: 'configure 진행?' }
stage('configure') { sh "ansible-playbook ... --tags configure" }
stage('verify')    { sh "ansible-playbook ... --tags verify"    }
```

## 자주 쓰는 모양

| 상황 | 예시 |
|---|---|
| 한 단계만 실행 | `--tags configure` |
| 여러 tag 동시 실행 | `--tags install,configure` |
| 특정 단계 제외 | `--skip-tags verify` |
| 어떤 tag 가 있는지 확인 | `--list-tags` (실제 실행 없이 tag 목록만) |
| 어떤 task 가 실행될지 미리보기 | `--list-tasks --tags verify` |
| 항상 실행 | task 에 `tags: always` |
| 명시할 때만 실행 | task 에 `tags: never` (외부에서 명시해야 실행) |

## 막힐 때 확인

> 증상: `--tags verify` 를 줬는데 verify task 가 실행되지 않는다.
>
> 확인할 것:
> - task 의 `tags` 가 정확히 같은 문자열인지 확인한다. 대소문자가 다르면 안 잡힌다.
> - role 안에 들어간 task 라면 role 자체에도 tag 가 자동으로 상속된다는 점을 기억한다.
> - `--list-tags` 로 현재 playbook 에 등록된 tag 목록을 먼저 확인한다.

> 증상: 어떤 tag 를 줘도 같은 task 가 계속 실행된다.
>
> 확인할 것:
> - 해당 task 에 `tags: always` 가 붙어 있지 않은지 확인한다.
> - 부모 `block` 또는 `roles` 레벨에 tag 가 붙어 있으면 그 안의 task 에 모두 상속된다.

## 실제 작업에서 어디 쓰이나

- `tasks/linux/nginx-healthcheck/` — `install` / `configure` / `verify` 세 tag 로 분리되어 있고, Jenkinsfile 이 stage 마다 다른 tag 로 같은 playbook 을 부른다.
- `tasks/linux/pkg-update/` — 사전 점검 / 업데이트 / 사후 점검이 단계별로 나뉘어 호출하기 쉽게 되어 있다.
- `patterns/import-include/` — 단계별로 다른 task 파일을 부르는 패턴과 같이 쓰면 stage 분리가 더 깔끔해진다.
