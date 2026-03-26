# Day1 작업 디렉터리

Day1 작업은 서버 최초 구성 시 수행하는 작업입니다.

## 예시 작업 유형

- OS 초기 설정 (hostname, timezone, NTP 초기 동기화)
- 필수 패키지 설치
- 보안 설정 (SELinux, 방화벽)
- 디스크 파티셔닝 및 마운트
- 에이전트 설치 (모니터링, 보안)

## 디렉터리 구조

```
day1/
  {작업명}/
    {OS타입}/
      Jenkinsfile
      site.yml
```

## 새 작업 추가 방법

GUIDE_FOR_AI.md 와 docs/jenkinsfile-guide.md 를 참고하여
Jenkinsfile + site.yml 을 작성하고 해당 디렉터리에 추가합니다.
