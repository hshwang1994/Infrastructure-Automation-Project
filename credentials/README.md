# 계정 관리 디렉토리 (Jenkins Credentials 원본)

이 디렉토리는 **Jenkins Credentials 에 등록되어야 할 자격증명의 원본 정의서**를 보관합니다.

## 역할

- Jenkins UI 에서 자격증명을 등록할 때 참조할 **단일 소스 (source of truth)**
- 어떤 target_type 에 어떤 계정이 매핑되는지 추적
- 운영 이행 시 값만 교체하면 됨 (코드 수정 불필요)

> 이 파일들 자체로 인증이 일어나는 게 아닙니다. 실제 인증은 Jenkins 가 보관 중인 Credential 로만 수행합니다.
> 이 디렉토리는 "Jenkins 에 무엇을 등록해야 하는가" 를 사람과 AI 가 추적하기 위한 명세입니다.

## 파일 목록

| 파일 | 대응 target_type | Jenkins 등록 |
|------|-----------------|------------|
| `linux.yml` | linux | `ansible-linux-*` |
| `windows.yml` | windows | `ansible-windows-*` |
| `esxi.yml` | esxi | `ansible-esxi-*` |
| `redfish.yml` | redfish | `ansible-redfish-*` |

Jenkins Credential ID 매핑과 등록 절차는 [`../docs/jenkinsfile-guide.md`](../docs/jenkinsfile-guide.md) 의 "Jenkins Credentials" 섹션 참고.

## 등록 흐름

```
credentials/{type}.yml  (이 파일들)
        ↓ 참고
Jenkins UI → Manage Jenkins → Credentials → Add Credentials
        ↓ 등록됨
ansiblePlaybook(credentialsId: 'ansible-{type}-...')
        ↓ 사용됨
실제 Ansible 인증
```

## 값 교체 절차 (사내 테스트 → 운영 이행)

1. 이 디렉토리의 해당 yml 파일에서 `username` / `password` 값 갱신
2. Jenkins UI 에서 같은 ID 의 Credential 을 같은 새 값으로 업데이트
3. 코드(Jenkinsfile / Playbook) 는 수정 없음 — `credentialsId` 만 참조하므로 그대로 동작
4. 새 값으로 테스트 1회 후 정상이면 완료

## 주의

- 사내 테스트 단계라 평문으로 둡니다. 운영 환경 이행 시 별도 비밀 관리(예: HashiCorp Vault, AWS Secrets Manager 등)로 이동을 고려하세요.
- 운영 자격증명을 이 디렉토리에 평문으로 둘 경우 저장소 접근 통제와 별도 암호화 검토가 필요합니다.
