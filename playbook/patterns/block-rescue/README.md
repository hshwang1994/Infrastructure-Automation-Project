# patterns/block-rescue — 실패하면 자동으로 되돌리기

운영 환경에서 sshd 재시작 같은 위험한 작업을 할 때, 잘못되면 어떻게 할지 미리 정해두지 않으면 사고가 난다. 예: sshd 설정 잘못 써서 sshd 가 죽으면 → SSH 끊김 → 복구하러 콘솔로 가야 함.

그러기 전에 "**잘못되면 백업으로 자동 복원**" 을 표현해두면 사고가 안 된다. Ansible 의 `block` / `rescue` / `always` 문법이 정확히 이걸 표현한다.

자바·파이썬의 `try / catch / finally` 와 같은 개념을 task 묶음에 적용한 거라고 보면 된다.

## 동작 흐름

```
block:    정상 경로 task 들
  ↓ 중 한 줄이라도 실패하면
rescue:   복구 task 들이 자동 실행 (catch 같은 것)
always:   성공·실패 무관 마지막에 무조건 실행 (로깅·정리·메트릭)
```

## 데모 시나리오

이 데모의 `site.yml` 은:

1. **block** 단계에서:
   - `/tmp/demo.txt` 에 "original" 작성 → 백업 (`.bak` 으로 복사) → "updated" 로 덮어씀
   - 마지막에 일부러 실패하는 task (`/bin/false`)
2. **rescue** 가 발동:
   - 백업으로 원본 복원
   - "변경 실패 — 복원함" 메시지
3. **always** 가 마지막에:
   - 종료 시각 기록

타깃에 영향은 `/tmp/demo.txt`, `/tmp/demo.txt.bak` 두 파일뿐. 안전하다.

## 직접 돌려보기

```bash
ansible-playbook -i 인벤토리 site.yml
```

PLAY RECAP 직전에 보면 rescue task 들이 실행된 게 보인다. 실제로 `/tmp/demo.txt` 내용을 확인하면 "updated" 가 아니라 "original" 로 복원돼 있다.

## 언제 쓰면 좋은가

- **운영 중인 설정·service 를 변경할 때** — 실패하면 이전 상태로 자동 복귀해야 사고 안 남
- **임시 디렉토리·락 파일** — 결과와 무관하게 정리해야 하는 자원이 있을 때 (`always` 가 담당)
- **알림·메트릭** — 작업이 성공해도 실패해도 무조건 결과를 남겨야 할 때

## 실제 작업에서 어디 쓰이나

`tasks/linux/sshd-safe-reload/` — sshd_config 변경 시 백업 + 검증 + 재시작. 실패하면 자동으로 백업으로 롤백 + sshd 재시작.
