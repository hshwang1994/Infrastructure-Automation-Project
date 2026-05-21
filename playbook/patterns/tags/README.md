# patterns/tags — 같은 playbook 에서 일부 단계만 골라 실행

배포 작업을 보면 보통 단계가 있다:

- 패키지 설치 — 한 번만, 시간 오래 걸림
- 설정 변경 — 자주 함
- 결과 확인 — 마지막에 잠깐

매번 전부 다 돌릴 필요는 없다. 설정만 갱신하고 싶을 수도, 검증만 따로 돌리고 싶을 수도. **tags** 는 한 playbook 안에 이 단계들을 적어두고, 호출 시 골라 돌릴 수 있게 해준다.

## 동작 흐름

task 마다 tag 를 붙임:

```yaml
- name: nginx 설치
  ...
  tags: install

- name: 설정 배치
  ...
  tags: configure

- name: 응답 확인
  ...
  tags: verify
```

호출 시 어떤 tag 만 돌릴지 선택:

```bash
ansible-playbook site.yml --tags install        # 설치만
ansible-playbook site.yml --tags configure      # 설정만
ansible-playbook site.yml --tags verify         # 검증만
ansible-playbook site.yml                       # tag 안 주면 전체
```

## 데모 시나리오

이 데모 site.yml 은 `/tmp/tagdemo/` 디렉토리에:

| stage     | tag         | task                    |
|:----------|:------------|:------------------------|
| install   | `install`   | 디렉토리 생성            |
| configure | `configure` | `app.conf` 파일 배치    |
| verify    | `verify`    | 파일 존재 확인 + 출력   |

## 직접 돌려보기

```bash
# 1) 전체 실행
ansible-playbook -i 인벤토리 site.yml

# 2) verify 만 (디렉토리·파일이 있어야 통과)
ansible-playbook -i 인벤토리 site.yml --tags verify

# 3) configure 만 다시 (설정만 갱신)
ansible-playbook -i 인벤토리 site.yml --tags configure
```

## Jenkins 다단계와 어떻게 만나나

Jenkinsfile 에서 stage 마다 같은 site.yml 을 다른 tag 로 호출하면, 사람이 사이사이 승인하거나 검토할 수 있다:

```
Install stage  →  ansiblePlaybook(playbook, tags: 'install')
   ↓ 운영팀 승인
Configure stage  →  ansiblePlaybook(playbook, tags: 'configure')
   ↓
Verify stage  →  ansiblePlaybook(playbook, tags: 'verify')
```

## 실제 작업에서 어디 쓰이나

`tasks/linux/nginx-healthcheck/` — nginx 설치 / `/etc/nginx/conf.d/healthcheck.conf` 배치 / `http://localhost/healthz` 응답 확인을 install·configure·verify tag 로 분리. Jenkinsfile 이 3 stage 로 호출.
