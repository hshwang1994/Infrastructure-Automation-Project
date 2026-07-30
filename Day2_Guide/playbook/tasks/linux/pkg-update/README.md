# tasks/linux/pkg-update — 보안 패치 적용

RHEL 계열은 dnf 보안 업데이트, Debian 계열은 apt safe-upgrade. 사전 점검 → 본 작업 → 사후 검증 3 단계로 안전하게 진행.

## 보여주는 패턴

- **Jenkinsfile 다단계 (3 stage)** — Pre-check / Update / Post-verify
- **playbook 파일 분리** — `pre.yml`, `update.yml`, `post.yml` 세 개
- **OS 분기** — `ansible_facts.os_family` 로 dnf/apt 자동 선택
- **assert + service_facts** — 디스크 여유공간 검증, 핵심 서비스(sshd) 정상 여부 검증

## stage 흐름

| stage       | playbook       | 내용                                                            |
| :---------- | :------------- | :-------------------------------------------------------------- |
| Pre-check   | `pre.yml`      | 루트 파티션 1 GB 이상 여유 확인, 패키지 매니저 식별 출력        |
| Update      | `update.yml`   | RHEL: `dnf security`, Debian: `apt upgrade: safe`               |
| Post-verify | `post.yml`     | `/var/run/reboot-required` 확인, sshd active 확인, 결과 요약    |

## 변경되는 것

타겟 호스트의 보안 패치가 최신으로 올라감. reboot 이 필요한 경우 별도 작업으로 분리 (이 playbook 은 재부팅 안 함).
