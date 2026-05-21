# sandbox/ — 연습용 슬롯

`tasks/` 가 실제 운영 작업, `patterns/` 가 문법 데모라면, `sandbox/` 는 **사용자가 직접 들어와서 yml 을 하나씩 수정해보면서 익히는 연습장**.

## 슬롯 구조

`user01/` ~ `user10/` 까지 **10개 슬롯이 모두 동일한 내용**으로 들어 있다. 각 슬롯은 1인이 점유해서 자유롭게 수정하면 됨. 다른 사람 슬롯과 충돌나지 않는다.

각 슬롯 안 (`user01/` 예시):

```
user01/
├── Jenkinsfile     3 stage (Pre-check / Main / Post-verify)
├── pre.yml         RHEL 9 환경 검증 + 호스트 정보 출력
├── main.yml        /tmp/practice.txt 작성
├── post.yml        파일 다시 읽어 내용 출력
└── README.md       이 슬롯 안내 + 어디 수정해서 연습할지
```

## 대상

**RHEL 9 (9.10) Linux** 만. `pre.yml` 의 assert 가 RHEL 9 이 아니면 fail 시켜서 환경 실수 방지.

## 왜 3 stage 인가

Jenkins 의 다단계 pipeline 흐름까지 같이 익히기 위함. 단일 stage 로 충분한 단순 작업도 일부러 **Pre / Main / Post** 로 쪼개서, "stage 사이에 검증/롤백을 끼우는 감각" 을 연습할 수 있게 했다.

## 사용 흐름

1. 본인 슬롯 하나 정함 (예: `user03`)
2. Jenkins Pipeline job 만들고 Script Path: `playbook/sandbox/user03/Jenkinsfile`
3. 일단 그대로 한 번 돌려서 성공 확인
4. yml 을 하나씩 수정해보면서 변화 관찰
5. 자세한 수정 아이디어는 각 슬롯의 README.md 참고

## 슬롯 사이의 차이

내용은 모두 동일. 단지 Jenkinsfile 안에 자기 슬롯 경로가 박혀 있을 뿐:

```
playbook          : "${WORKSPACE}/playbook/sandbox/userNN/{pre,main,post}.yml"
```

처음 점유할 때 비교용으로 `git diff` 떠보면, 슬롯 간 차이가 path 문자열 3줄뿐인 것을 확인할 수 있다.

## 운영 작업으로 만들면 안 됨

이건 **연습용**. 실 운영 호스트를 `inventory_json` 으로 가리키지 말 것. 운영 작업을 만들려면 [`playbook/tasks/`](../tasks/) 안에 새 디렉토리를 만드는 게 맞다.
