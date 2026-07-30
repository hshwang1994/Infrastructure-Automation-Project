# patterns/runner-master-portal-callback — OS/ESXi 프로비저닝 액션 + 포털 배포단계 갱신 예제

`example_action` Role 을 여러 호스트에 실행하고, 전체 성공 시에만 각 호스트의 배포단계를 포털에 기록하는 참조 구현.

## 통신 구조

```
Jenkins Master (built-in)                Jenkins Runner (params.loc)
┌─────────────────────────┐              ┌─────────────────────────┐
│ Validate                │              │                         │
│  - callbackUrl 검증     │              │                         │
│  - inventory_json 검증  │              │                         │
├─────────────────────────┤   trigger    ├─────────────────────────┤
│                         │ ───────────▶ │ Run Ansible             │
│                         │              │  - inventory.sh 로      │
│                         │              │    inventory_json 파싱  │
│                         │              │  - example_action Role  │
│                         │              │    을 모든 호스트에 실행 │
│                         │  exit code   │                         │
│                         │ ◀─────────── │                         │
├─────────────────────────┤              └─────────────────────────┘
│ Update Deployment Step  │
│  - inventory_json 에서  │
│    hostName 전체 추출   │
│  - 호스트별 포털 API    │───▶ Portal
│    POST (최대 3회 재시도)│
└─────────────────────────┘
```

Runner 는 포털과 통신할 수 없는 망이라 포털 API 호출은 하지 않는다 — Ansible 실행 결과(성공/실패, exit code)만으로 파이프라인이 판단한다. Ansible 이 0이 아닌 코드로 끝나면 `ansiblePlaybook()` 스텝이 그 자리에서 파이프라인을 실패시켜 `Update Deployment Step` Stage 자체가 실행되지 않는다.

## 다중 호스트 실행

`inventory_json` 배열의 모든 호스트가 `Run Ansible` Stage 에서 동시에 처리된다 (`site.yml` 의 `hosts: all`). Ansible 전체 실행이 성공(모든 호스트 성공)해야만 다음 Stage 로 넘어가며, 이때 Jenkins Master 는 Ansible 실행 결과가 아니라 **원본 `inventory_json` 파라미터**에서 다시 `hostName` 목록을 추출해 포털에 순서대로 전달한다.

호스트 하나라도 포털 API 최종 실패(3회 재시도 소진)하면 빌드는 `UNSTABLE` 로 표시되고 실패 호스트 목록이 로그에 남는다. `deploymentStep` 값은 별도 파라미터가 아니라 실행 중인 Jenkins Job 이름(`env.JOB_BASE_NAME`)을 그대로 쓴다.

## 파라미터

| 파라미터 | 예시 | 설명 |
| :--- | :--- | :--- |
| `loc` | `git` | Ansible 을 실행할 Runner 라벨 |
| `inventory_json` | `[{"hostname":"WIN-TP7D9J9QKCB","ansible_host":"10.100.64.120"}]` | 대상 호스트 배열 — `hostname`/`hostName` 은 필수, 그 외 필드(`ansible_host`, `ansible_user` …)는 `inventory.sh` 가 그대로 hostvar 로 전달 |
| `callbackUrl` | `http://<portal-host>:<port>` | 포털 base URL. Jenkinsfile 이 `/api/jenkins/logical/server/deployment/step` 을 붙여 호출 |

## Jenkins Script Path

`Day2_Guide/playbook/patterns/runner-master-portal-callback/Jenkinsfile`

## 관리자 준비사항 (Jenkins 쪽에서 손대야 하는 것)

| 항목 | 상태 | 설명 |
| :--- | :--- | :--- |
| Jenkins job 등록 | ✅ 완료 | `example-provisioning-portal-notify`, GitHub(origin) SCM, Script Path 위 경로로 설정됨 |
| `http_request` 플러그인 | ✅ 이미 설치됨 | 포털 API 호출(`httpRequest` 스텝)에 사용 |
| `pipeline-utility-steps` 플러그인 | ✅ 이미 설치됨 | `readJSON`/`writeJSON` 스텝에 사용 |
| Ansible 설치(`installation: 'ansible'`) | ✅ 기존 설정 재사용 | 다른 job들과 동일한 Jenkins Ansible 툴 설정 사용, 별도 작업 불필요 |
| **전역 Shared Library GitLab 인증** | ❌ **막혀있음 — 최우선 처리 필요** | `Manage Jenkins → System → Global Trusted Pipeline Libraries → jenkins-shared-lib` 가 GitLab(`10.100.64.156/root/jenkins-shared-lib.git`)을 크리덴셜 `포털계정`으로 체크아웃하는데 인증 실패 중. **이게 막혀있으면 이 job 뿐 아니라 이 Jenkins의 모든 파이프라인이 시작 단계에서 실패한다.** `Manage Jenkins → Credentials` 에서 유효한 계정/비번으로 크리덴셜을 고치거나 새로 만들어서 라이브러리 설정이 그걸 가리키게 연결 필요 |
| `callbackUrl` 실제 값 | ⚠️ 매 빌드 입력 필요 | 코드에 하드코딩하지 않음(요청사항) — Build with Parameters 할 때마다 실제 포털 base URL을 직접 입력해야 함 |
| 대상 호스트 접속 자격증명 | ⚠️ 매 빌드 입력 필요 | vault 미사용 — `inventory_json` 항목에 `ansible_user`/`ansible_password`(또는 winrm 관련 필드) 를 직접 넣어서 전달. 고정 계정을 쓰고 싶으면 vault 방식으로 바꾸는 확장 작업 별도 필요 |
