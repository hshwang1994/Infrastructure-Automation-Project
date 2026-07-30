# tasks/windows/service-healthcheck — IIS + `/healthz` 배포

`ansible.windows.win_feature` 로 IIS 를 설치하고, `/healthz.txt` 헬스체크 페이지를 배치한 뒤 `win_uri` 로 200 응답을 확인한다. Linux `nginx-healthcheck` 의 Windows 대응. install / configure / verify **태그** 로 부분 실행이 가능하다.

## 보여주는 패턴

- **tags 로 단계 분리** — `install` / `configure` / `verify` 를 태그로 나눠 부분 실행
- **windows 특화 모듈 조합** — `win_feature`(역할 설치) + `win_copy` + `win_service` + `win_uri`
- **handler** — 헬스체크 페이지 변경 시 `W3SVC` 재시작
- **재부팅 처리** — 역할 설치 후 `reboot_required` 이면 `win_reboot`

## task 흐름 (site.yml)

| 태그      | 하는 일                                                         |
| :-------- | :------------------------------------------------------------- |
| install   | `win_feature: Web-Server` (IIS) 설치, 필요 시 재부팅          |
| configure | `healthz.txt` 배치 + `W3SVC` 시작/자동, 변경 시 handler 재시작 |
| verify    | `win_uri` 로 `http://localhost/healthz.txt` 200 확인          |

## 부분 실행 예

```bash
# 검증만 다시
ansible-playbook site.yml --tags verify
# 설치 건너뛰고 설정부터
ansible-playbook site.yml --skip-tags install
```

## 변경되는 것

- IIS(Web-Server) 역할 설치
- `C:\inetpub\wwwroot\healthz.txt` 생성
- `W3SVC` 서비스 시작/자동 설정

## 같은 패턴 학습용 데모

[`patterns/tags/`](../../../patterns/tags/) — tags 최소 예시.
