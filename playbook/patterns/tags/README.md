# patterns/tags — tags 로 단계별 부분 실행

같은 playbook 을 **여러 stage 에서 부분만 실행**하고 싶을 때 쓰는 패턴. Jenkins 다단계 pipeline 이 stage 마다 `--tags install`, `--tags configure`, `--tags verify` 같이 호출하면, 동일한 site.yml 이 각 stage 에서 자기 부분만 돌게 된다.

## 구조

```yaml
tasks:
  - name: 설치 단계
    ...
    tags: install

  - name: 설정 단계
    ...
    tags: configure

  - name: 검증 단계
    ...
    tags: verify
```

## 데모 시나리오

`/tmp/tagdemo/` 디렉토리에 install / configure / verify 세 단계로 파일을 작성·검증. 각각 다른 tag 가 붙어 있어서, 호출 시 `--tags <이름>` 으로 한 부분만 실행 가능.

```
ansible-playbook site.yml --tags install
ansible-playbook site.yml --tags configure
ansible-playbook site.yml --tags verify
ansible-playbook site.yml                  # 태그 안 지정하면 모두 실행
```

## 언제 쓰나

- Jenkins 같은 외부 오케스트레이터가 **단계 사이에 승인·휴식 시간**을 두고 싶을 때
- 한 playbook 안에 **재실행이 잦은 부분**(설정 갱신)과 **드물게 실행하는 부분**(설치) 이 섞여 있을 때
- 검증 부분만 따로 돌려서 **smoke test** 처럼 쓰고 싶을 때

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/nginx-healthcheck/`](../../tasks/linux/nginx-healthcheck/) — nginx 설치 / healthcheck conf 배치 / `/healthz` 응답 검증을 install·configure·verify 태그로 분리, Jenkinsfile 이 3 stage 로 호출.
