# tasks/linux/disk-check — 디스크 사용량 점검

`df -h`, `df -i`, `find` 출력을 모아서 호스트별로 한 번에 보여준다.

## 보여주는 패턴

- **shell / command 만 사용** — 특화 모듈 없이 raw 명령 결과를 직접 가공
- **gather_facts: false** — facts 수집이 필요 없으니 SSH 비용 절약
- **changed_when: false** — 읽기 전용 명령이라 항상 OK 처리
- **failed_when: false** — `find` 가 일부 디렉토리에서 권한 거부로 fail 해도 무시

## task 흐름 (site.yml)

1. `df -h --output=source,size,used,avail,pcent,target` — 마운트별 사용량
2. `df -i` — inode 사용량
3. `find / -xdev -type f -size +100M | head -5` — 100MB 초과 파일 상위 5개
4. 위 결과들을 호스트별 단일 debug 메시지로 묶어 출력

## 변경되는 것

없음. 순수 조회 작업.

## 언제 이 패턴을 쓰나

타겟 환경에서 다루기 까다로운 출력 (특화 모듈이 없거나 모듈 출력이 부족할 때) 을 직접 가공해야 할 때. windows 쪽은 [`tasks/windows/sysinfo/`](../../windows/sysinfo/) 가 동일 컨셉을 `win_shell` 로 푼다.
