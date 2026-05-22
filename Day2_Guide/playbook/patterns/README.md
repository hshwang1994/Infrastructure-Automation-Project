# patterns/ — Ansible 문법·구조 데모

`tasks/` 가 "**무엇을 하는가**" 라면 `patterns/` 는 "**Ansible 의 이 문법은 어떻게 생겼고, 왜 필요한가**" 를 보여주는 자리다.

처음 Ansible 을 접한 사람이 각 패턴이 **왜 필요한지** 부터 시작해서, 실제 동작·직접 실행·실무 적용 예시까지 한 디렉토리 안에서 확인할 수 있도록 구성했다.

학습용이라 Jenkinsfile 없이 **작은 `site.yml` + `README.md`** 한 쌍으로만 (필요시 추가 파일 한두 개). 모두 `/tmp/` 영역만 건드려서 안전하게 반복 실행 가능.

## 데모 목록

| 디렉토리                                | 한 줄 요약                                              |
| :-------------------------------------- | :------------------------------------------------------ |
| [`roles/`](roles/)                      | task 묶음을 재사용 가능한 단위로 분리 (함수·라이브러리 같은 것) |
| [`block-rescue/`](block-rescue/)        | 실패하면 자동으로 되돌리기 (try/catch/finally)          |
| [`tags/`](tags/)                        | 같은 playbook 에서 일부 단계만 골라 실행                |
| [`handlers/`](handlers/)                | 설정이 바뀌었을 때만 서비스 재시작                      |
| [`conditionals/`](conditionals/)        | 호스트나 상황에 따라 다르게 실행 (`when:`)              |
| [`loops/`](loops/)                      | 같은 task 를 여러 번 반복 (`loop:`)                     |
| [`templates/`](templates/)              | 설정 파일을 호스트별로 동적 생성 (Jinja2)               |
| [`assert-fail/`](assert-fail/)          | 시작 전에 조건 검증해서 사고 막기                       |
| [`register-when/`](register-when/)      | 이전 결과를 기억해서 다음 분기에 쓰기                   |
| [`import-include/`](import-include/)    | task 파일을 여러 개로 쪼개기                            |
| [`lookup/`](lookup/)                    | 컨트롤러 쪽에서 동적 값 가져오기                        |
| [`delegate-runonce/`](delegate-runonce/)| 다른 호스트에서 실행 / 한 번만 실행                     |

## 권장 학습 순서

처음 Ansible 을 접한다면 다음 순서가 자연스럽다:

1. **`handlers/`** — 서비스 재시작 멱등성 (가장 직관적)
2. **`conditionals/`** — `when:` 으로 분기
3. **`loops/`** — 반복 처리
4. **`register-when/`** — 결과 → 다음 분기 (자주 같이 쓰는 흐름)
5. **`templates/`** — 설정 파일 동적 생성
6. **`assert-fail/`** — 안전한 사전 검증
7. **`block-rescue/`** — 실패 시 롤백 (복합 패턴)
8. **`tags/`** — 단계별 실행 (Jenkins 다단계와 결합)
9. **`roles/`** — 코드 재사용 구조
10. **`import-include/`** — task 파일 분리
11. **`lookup/`** — 컨트롤러 측 동적 값
12. **`delegate-runonce/`** — 위임 / 한 번만

## 직접 실행해보기

각 데모는 동적 인벤토리(`inventory/my_inventory.sh`) + 환경변수 한 쌍만 있으면 단독 실행할 수 있다.

```bash
export TARGET_TYPE=linux
export INVENTORY_JSON='[{"hostname":"rhel9-dev-01","service_ip":"192.168.0.10"}]'

ansible-playbook -i inventory/my_inventory.sh \
  playbook/patterns/{이름}/site.yml
```

각 README 의 "직접 돌려보기" 섹션에 실행 전 확인 사항과 회차별로 무엇이 어떻게 달라지는지 적혀 있다.
