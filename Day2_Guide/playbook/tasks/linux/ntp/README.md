# tasks/linux/ntp — NTP 동기화 점검

chronyd 서비스를 띄우고 `chronyc tracking` 으로 현재 시각 동기 상태를 출력한다.

## 보여주는 패턴

- **단일 stage Jenkinsfile** — 한 번의 `ansiblePlaybook` 호출
- **빌트인 모듈 혼합 사용** — `ansible.builtin.systemd`, `ansible.builtin.command`, `ansible.builtin.debug`

## task 흐름 (site.yml)

1. `chronyd` 서비스 started + enabled
2. `chronyc tracking` 실행 → `tracking` 변수에 결과 저장 (changed_when: false 로 idempotent)
3. 호스트별 tracking 결과 debug 출력

## 변경되는 것

`chronyd` 가 안 떠 있던 호스트에서는 서비스 시작 + 부팅 시 자동 시작. 이미 떠 있으면 변화 없음.
