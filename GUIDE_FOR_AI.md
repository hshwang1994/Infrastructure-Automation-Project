# GUIDE FOR AI

이 파일과 repo 코드를 함께 AI 에 업로드하면, AI 가 이 repo 의 컨벤션에 맞게 새 작업의 Jenkinsfile 과 site.yml 을 자동 생성해준다.

---

## 이 Repo 의 구조

```
Infrastructure-Automation-Project/
  inventory/
    my_inventory.sh        ← 동적 인벤토리 스크립트 (모든 작업에서 공통 사용)
  vault/
    linux.yml              ← Linux 접속 계정 (plain text, GitLab 접근 권한으로 보안 통제)
    windows.yml            ← Windows 접속 계정
    esxi.yml               ← ESXi 접속 계정
    redfish/
      lenovo.yml           ← Lenovo BMC 접속 계정
      dell.yml
      hpe.yml
  playbooks/
    day1/                  ← OS 설치 등 최초 구성 작업 (현재 README.md 플레이스홀더)
    day2/                  ← NTP, 패치, 펌웨어 등 운영 작업
  docs/                    ← Jenkinsfile/playbook 작성 가이드
    jenkins-guide.md
    playbook-guide.md
```

---

## Jenkinsfile 컨벤션

- `loc`, `target_type` → 포털이 전달. `defaultValue: ''`
- `inventory_json` → 포털이 조립하여 전달. `defaultValue` 는 포털 jspreadsheet 컬럼 정의로 사용됨
- `REPO_ROOT = "${WORKSPACE}"` → vault / inventory 경로 참조 기준
- `inventory` 경로 → `"${WORKSPACE}/inventory/my_inventory.sh"`
- `vaultCredentialsId` 없음 — vault 파일이 repo 에 plain text 로 포함
- Checkout Common Stage 없음 — 단일 repo 구조

## site.yml 컨벤션

- `hosts: all` — my_inventory.sh 가 모든 호스트를 all 그룹으로 출력
- vault 참조 → `"{{ lookup('env', 'REPO_ROOT') }}/vault/타입.yml"`
- inventory_hostname:
  - hostname 있음 (linux/windows/esxi) → hostname 값, `ansible_host` 에 ip
  - hostname 없음 (redfish) → ip 값

## inventory_json 필드

| 필드 | 필수 여부 | 설명 |
|------|----------|------|
| `ip` | 필수 | Ansible 접속 IP |
| `hostname` | linux/windows/esxi 필수 | inventory_hostname. Ansible 결과 로그에 표시 |
| `vendor` | redfish 필수 | lenovo / dell / hp |
| `service_ip` | os-provisioning 필수 | 포털 후속 Job 연계용 — 제거 금지 |
| `os_hostname` | os-provisioning 필수 | OS 내부에 적용할 hostname |
| `firmware_version` | firmware-update 선택 | 미입력 시 최신 버전 |

## 부하 테스트

Jenkins/Ansible 부하 테스트는 별도 레포 `jenkins-load-test` 에서 관리합니다.
이 repo 에는 부하 테스트 코드가 없습니다.

---

## AI 에게 새 작업 요청 예시

```
이 repo 코드와 GUIDE_FOR_AI.md 를 참고해서
playbooks/day2/ntp-sync/linux/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
NTP 서버 동기화 작업이고 대상은 Linux 야.
```
