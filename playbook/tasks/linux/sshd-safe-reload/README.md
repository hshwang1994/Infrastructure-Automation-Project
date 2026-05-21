# tasks/linux/sshd-safe-reload — sshd 안전 재시작

`/etc/ssh/sshd_config` 를 백업한 뒤 `sshd -t` 로 유효성 검사 → sshd 재시작 → 22 포트 응답 확인. 어디서든 실패하면 자동으로 백업 파일로 롤백한다.

## 보여주는 패턴

- **block / rescue / always** — 정상 경로(block) / 실패 시 복구(rescue) / 항상 실행(always)
- **delegate_to: localhost** — `wait_for` 로 22 포트 응답을 ansible 컨트롤러에서 확인
- **잘못된 sshd 설정으로 SSH 세션이 끊기는 사고 방지**

## task 흐름 (site.yml)

```
block:
  1. /etc/ssh/sshd_config → /etc/ssh/sshd_config.bak 복사
  2. sshd -t 로 설정 유효성 검사
  3. sshd 재시작
  4. wait_for 로 22 포트 응답 확인 (localhost 에서)

rescue (위 중 어디서든 실패 시):
  1. sshd_config.bak 으로 원본 복원
  2. sshd 재시작 (롤백 적용)
  3. fail 메시지로 결과 알림

always:
  - 종료 시각 기록
```

## 변경되는 것

- 새 파일: `/etc/ssh/sshd_config.bak` (백업)
- 잠재적 변경: sshd 재시작 (config 자체는 이 playbook 에서 수정하지 않음 — 실제 사용 시 block 안에 설정 변경 task 를 추가)

## 같은 패턴 학습용 데모

[`patterns/block-rescue/`](../../../patterns/block-rescue/) — `/tmp/demo.txt` 로 block/rescue/always 흐름만 보여주는 최소 예시.
