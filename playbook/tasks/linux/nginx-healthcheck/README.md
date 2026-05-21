# tasks/linux/nginx-healthcheck — nginx + /healthz 엔드포인트 배포

nginx 를 설치하고 `/healthz → 200 ok` 응답하는 default_server conf 를 배치, 마지막에 `uri` 모듈로 응답을 직접 검증.

## 보여주는 패턴

- **tags 로 단계 분리** — `install` / `configure` / `verify` 3 단계
- **Jenkinsfile 다단계 + 같은 playbook 재호출** — 한 site.yml 을 stage 마다 `tags:` 다르게 줘서 호출
- **handler (`notify: restart nginx`)** — conf 가 바뀌었을 때만 nginx 재시작
- **uri 모듈로 자기 검증** — 외부 의존성 없이 playbook 안에서 헬스체크

## stage / tag 매핑

| Jenkins stage | tag         | 내용                                                                                |
| :------------ | :---------- | :---------------------------------------------------------------------------------- |
| Install       | `install`   | nginx 패키지 설치                                                                   |
| Configure     | `configure` | `/etc/nginx/conf.d/healthcheck.conf` 배치 + nginx 시작·활성화 (변경 시 notify)      |
| Verify        | `verify`    | `http://localhost/healthz` 호출 → status_code 200 확인 + 응답 본문 출력             |

`ansible-playbook site.yml --tags install` 같은 식으로 부분만 돌리는 것도 가능.

## 변경되는 것

- nginx 패키지 설치
- 새 파일: `/etc/nginx/conf.d/healthcheck.conf` (80 포트 default_server, `/healthz` 핸들러)
- nginx 시작 + 부팅 시 자동 시작

## 같은 패턴 학습용 데모

[`patterns/tags/`](../../../patterns/tags/) — `/tmp/tagdemo/` 디렉토리로 install/configure/verify 태그 분리만 보여주는 최소 예시.
