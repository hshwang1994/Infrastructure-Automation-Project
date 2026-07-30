# tasks/windows/win-updates — Windows Update 적용 (Pre / Update / Post)

`ansible.windows.win_updates` 로 **보안·중요 업데이트** 를 검색·설치·검증한다. Linux `pkg-update` (dnf/apt 보안 패치) 의 Windows 대응. Jenkinsfile 3 stage + playbook 분리 구조를 그대로 따른다.

## 보여주는 패턴

- **Jenkinsfile 3 stage** — Pre-check / Update / Post-verify, 각 stage 가 별도 playbook 호출
- **playbook 분리** — `pre.yml` / `update.yml` / `post.yml`
- **windows 특화 모듈** — `win_updates` (검색 `state: searched`, 설치, `reboot_required` 반환)
- **재부팅 분리 처리** — 설치는 `reboot: false`, 이후 `reboot_required` 일 때만 `win_reboot` (베스트프랙티스)

## stage 흐름

| stage       | playbook     | 하는 일                                                      |
| :---------- | :----------- | :----------------------------------------------------------- |
| Pre-check   | `pre.yml`    | `state: searched` 로 대기 업데이트 건수만 조회 (설치 안 함)  |
| Update      | `update.yml` | 설치(`reboot: false`) → `reboot_required` 시에만 `win_reboot` |
| Post-verify | `post.yml`   | 재검색해서 남은 보안·중요 업데이트 건수 확인                 |

## 변경되는 것

- SecurityUpdates / CriticalUpdates 카테고리 업데이트 설치
- 재부팅이 필요한 경우 대상 호스트 재부팅

## 카테고리 조정

`category_names` 목록을 바꾸면 대상 범위가 달라진다 (예: `UpdateRollups` 추가). 전체는 `['*']`.
