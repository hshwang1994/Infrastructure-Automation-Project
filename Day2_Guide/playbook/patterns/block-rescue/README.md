# patterns/block-rescue — 실패하면 자동으로 되돌리기

`block` / `rescue` / `always` 는 여러 task 를 한 묶음으로 묶어 실패 시 복구 흐름을 정의한다.
`block` 안에서 한 task 라도 실패하면 `rescue` 가 자동으로 돌고, 그 뒤 `always` 가 무조건 실행된다.

## 왜 필요한가

운영 환경에서는 sshd 재시작이나 설정 파일 교체처럼 한 번 실패하면 바로 사고로 이어지는 작업이 있다.
sshd 설정을 잘못 바꾼 채 재시작했다가 데몬이 죽으면 SSH 가 끊겨 콘솔로 복구하러 가야 한다.
이런 작업은 "성공 경로 + 실패 복구 + 무조건 정리" 세 단계를 묶어 한꺼번에 표현하는 편이 안전하다.
`block` / `rescue` / `always` 는 자바·파이썬의 `try / catch / finally` 와 같은 개념을 task 묶음에 적용한 것이다.
Jenkinsfile 의 `try { } catch { } finally { }` 가 Ansible 안에 그대로 들어왔다고 보면 된다.

## 먼저 알아둘 말

- `block` — 정상 경로 task 들을 묶는 구역이다.
- `rescue` — `block` 안 task 중 하나라도 실패하면 자동으로 실행되는 복구 구역이다.
- `always` — 성공·실패와 관계없이 반드시 실행되는 마무리 구역이다.
- 실패 판정 — task 모듈의 기본 실패 조건 또는 `failed_when:` 으로 정의한 조건이다.

## 최소 예제

`block` 안에서 마지막 task 가 실패하면 `rescue` 가 자동으로 실행된다.

```yaml
- name: 안전한 변경 시도
  block:
    - name: 새 내용 작성
      ansible.builtin.copy:
        content: "updated\n"
        dest: /tmp/demo.txt

    - name: 의도적 실패
      ansible.builtin.command: /bin/false

  rescue:
    - name: 실패 사실 알림
      ansible.builtin.debug:
        msg: "변경 실패 — 복원 절차 시작"
```

`/bin/false` 가 실패하면 `rescue` 분기로 넘어가 `debug` 메시지가 출력된다.
실패가 없으면 `rescue` 는 실행되지 않는다.

## 전체 예제 흐름

`site.yml` 은 "백업 → 새 내용 → 의도적 실패 → 백업 복원 → 종료 시각 기록" 흐름이다.

```yaml
tasks:
  - name: 안전한 변경 시도
    block:
      - name: 원본 백업
        ansible.builtin.copy:
          content: "original\n"
          dest: /tmp/demo.txt

      - name: 백업 복사
        ansible.builtin.copy:
          src: /tmp/demo.txt
          dest: /tmp/demo.txt.bak
          remote_src: true

      - name: 새 내용 작성
        ansible.builtin.copy:
          content: "updated\n"
          dest: /tmp/demo.txt

      - name: 의도적 실패
        ansible.builtin.command: /bin/false

    rescue:
      - name: 백업으로 복원
        ansible.builtin.copy:
          src: /tmp/demo.txt.bak
          dest: /tmp/demo.txt
          remote_src: true

      - name: 실패 사실 알림
        ansible.builtin.debug:
          msg: "변경 실패 — 백업으로 복원함"

    always:
      - name: 종료 시각 기록
        ansible.builtin.debug:
          msg: "종료 {{ ansible_date_time.iso8601 }}"
```

실행 순서는 다음과 같다.

1. `block` 의 첫 task 가 `/tmp/demo.txt` 에 `original` 을 쓴다.
2. 그 파일을 `.bak` 으로 복사해 둔다.
3. 같은 위치에 `updated` 를 덮어쓴다.
4. `/bin/false` 가 일부러 실패한다.
5. `rescue` 가 발동해 `.bak` 으로 원본을 되돌리고 안내 메시지를 남긴다.
6. `always` 가 마지막에 종료 시각을 남긴다.

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
  playbook/patterns/block-rescue/site.yml
```

### 기대 결과

```text
TASK [원본 백업] **************************************
changed: [rhel9-dev-01]

TASK [백업 복사] **************************************
changed: [rhel9-dev-01]

TASK [새 내용 작성] ***********************************
changed: [rhel9-dev-01]

TASK [의도적 실패] *************************************
fatal: [rhel9-dev-01]: FAILED! => {"rc": 1, ...}

TASK [백업으로 복원] ************************************
changed: [rhel9-dev-01]

TASK [실패 사실 알림] ************************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 변경 실패 — 백업으로 복원함"
}

TASK [종료 시각 기록] ************************************
ok: [rhel9-dev-01] => {
    "msg": "rhel9-dev-01: 종료 2026-..."
}

PLAY RECAP **********************************************
rhel9-dev-01 : ok=6 changed=4 rescued=1 failed=0
```

`rescued=1` 은 `rescue` 분기가 작동했다는 표시다. 호스트 입장에서는 실패가 복구되어 최종적으로 `failed=0` 이다.

## 두 번째 실행에서 볼 것

같은 playbook 을 다시 돌려도 흐름은 같다.
첫 `copy` 는 같은 내용이라 `ok` 로 끝나고, 의도적 실패는 그대로 발동되고, `rescue` 는 다시 백업으로 되돌린다.
"실패가 나도 자동으로 안전한 상태로 수렴한다" 는 점이 두 번째 실행에서 더 분명히 보인다.
실제 작업에서는 `/bin/false` 대신 검증 task 가 들어가므로, 두 번째 실행 시 검증을 통과해 `rescue` 가 발동되지 않아야 정상이다.

## 자주 쓰는 모양

| 상황 | 구성 |
|---|---|
| 설정 변경 + 검증 + 자동 롤백 | `block`(백업 → 변경 → 검증) + `rescue`(백업 복원) |
| 임시 자원 정리 | `block`(작업) + `always`(임시 파일 / lock 제거) |
| 실패 알림 | `rescue`(slack/webhook 알림) |
| 부분 복구 + 재시도 | `rescue` 안에 다시 작업 시도 task |
| 무조건 메트릭 송출 | `always`(로그 / 종료 시각 / 카운터) |
| 실패를 성공으로 흡수 | `rescue` 안에서 정상 종료 처리 (`failed_when` 과 같이 활용) |

## 실제 작업에서 어디 쓰이나

- `tasks/linux/sshd-safe-reload/` — `sshd_config` 변경 시 백업 + 검증 + 재시작을 `block` 으로 묶고, 실패하면 `rescue` 에서 백업으로 자동 롤백한다.
- `patterns/assert-fail/` — 사전 검증으로 시작 자체를 막는 패턴. `block-rescue` 와 짝이 잘 맞는다.
- `patterns/handlers/` — `rescue` 에서 복원 후 handler 로 서비스 재시작을 묶는 흐름.
