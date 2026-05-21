# patterns/block-rescue — block / rescue / always

여러 task 를 묶어서 **하나라도 실패하면 자동으로 복구 단계 실행**, 성공·실패 무관하게 **마무리 단계 실행** 하는 패턴.

## 구조

```
block:    여러 task 묶음 (정상 경로)
  ↓ 중 어디서든 실패하면
rescue:   실패 시 실행 (롤백/복구)
always:   성공·실패 무관 마무리 (로깅/정리)
```

## 데모 시나리오

`/tmp/demo.txt` 를 백업 → 새 내용 작성 → 의도적으로 실패 task 실행. 실패 직후 rescue 가 백업 파일로 복원하고, always 가 종료 시각을 남긴다.

타겟 시스템에는 `/tmp/demo.txt`, `/tmp/demo.txt.bak` 만 영향.

## 언제 쓰나

- 운영 중인 설정·서비스를 변경할 때 **실패 시 이전 상태로 자동 복귀**가 필요한 경우
- 임시 디렉토리/락 파일 등 **반드시 정리해야 하는 리소스**가 있는 경우
- 알림·메트릭 기록처럼 **결과와 무관하게 항상 실행해야 하는 후처리**가 있는 경우

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/sshd-safe-reload/`](../../tasks/linux/sshd-safe-reload/) — sshd_config 백업 후 재시작, 실패 시 백업으로 자동 롤백.
