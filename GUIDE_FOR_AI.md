# GUIDE FOR AI

이 파일과 repo 코드를 함께 AI 에 업로드하면, AI 가 이 repo 의 컨벤션에 맞게 새 작업의 Jenkinsfile 과 site.yml 을 자동 생성해준다.

---

## Repo 구조

```
Infrastructure-Automation-Project/
  inventory/
    my_inventory.sh        ← 동적 인벤토리 스크립트 (모든 작업에서 공통 사용)
  vault/
    linux.yml              ← Linux 접속 계정
    windows.yml            ← Windows 접속 계정
    esxi.yml               ← ESXi 접속 계정
    redfish/
      dell.yml             ← Dell BMC 접속 계정
      hpe.yml
      lenovo.yml
      supermicro.yml
  playbooks/
    day1/                  ← 서버 최초 구성 작업
    day2/                  ← 운영 작업 (NTP, 패치, 펌웨어 등)
  docs/
    jenkinsfile-guide.md   ← Jenkinsfile 작성 표준 (필독)
    playbook-guide.md      ← Playbook 작성 표준 (필독)
```

## 상세 컨벤션

- **Jenkinsfile 작성**: `docs/jenkinsfile-guide.md` 참조
- **Playbook 작성**: `docs/playbook-guide.md` 참조

## 부하 테스트

Jenkins/Ansible 부하 테스트는 별도 레포에서 관리합니다.
이 repo 에는 부하 테스트 코드가 없습니다.

---

## AI 에게 새 작업 요청 예시

```
이 repo 코드와 GUIDE_FOR_AI.md 를 참고해서
playbooks/day2/ntp-sync/linux/ 에 들어갈 Jenkinsfile 과 site.yml 을 만들어줘.
NTP 서버 동기화 작업이고 대상은 Linux 야.
```
