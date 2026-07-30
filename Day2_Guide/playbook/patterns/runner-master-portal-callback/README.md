# patterns/runner-master-portal-callback — Runner 실행 + Master 전용 포털 배포단계 갱신

`example_action` Role 을 Runner 에서 여러 호스트에 실행하고, 성공하면 Jenkins Master(`built-in`)가 각 호스트의 배포단계를 포털에 기록하는 참조 구현.

## 통신 구조

```
stage('Run Ansible')                       stage('Update Deployment Step')
agent: params.loc && params.target_type    agent: built-in
┌─────────────────────────┐                ┌─────────────────────────┐
│ inventory_json 의 모든   │   exit code    │ inventory_json 에서      │
│ 호스트에 example_action  │ ─────────────▶ │ hostName 전체 추출       │
│ Role 실행                │                │ 호스트별 포털 API POST   │──▶ Portal
│                          │                │ (최대 3회 재시도)        │
└─────────────────────────┘                └─────────────────────────┘
```

Runner 는 포털과 통신할 수 없는 망이라 포털 API 호출은 하지 않는다. `stage('Run Ansible')` 은 다른 `tasks/linux`, `sandbox` Jenkinsfile 과 동일하게 최상위 `agent`(`params.loc && params.target_type`) 를 그대로 쓰고, `stage('Update Deployment Step')` 만 `agent { label 'built-in' }` 로 override 해서 Jenkins Master 에서 돈다.

Ansible 이 0이 아닌 코드로 끝나면 `ansiblePlaybook()` 스텝이 그 자리에서 파이프라인을 실패시켜 `Update Deployment Step` 자체가 실행되지 않는다 — `catchError`/`ignore_errors` 없음.

## 다중 호스트 실행

`inventory_json` 배열의 모든 호스트가 `Run Ansible` stage 에서 처리된다(`site.yml` 의 `hosts: all`, 인벤토리는 Agent 의 공용 동적 인벤토리 사용 — 이 저장소 다른 작업들과 동일). 전체 성공해야만 다음 stage 로 넘어가며, Jenkins Master 는 Ansible 실행 결과가 아니라 **원본 `inventory_json` 파라미터**에서 다시 `hostName` 목록을 추출해 포털에 순서대로 전달한다.

호스트 하나라도 포털 API 최종 실패(3회 재시도 소진)하면 빌드는 `UNSTABLE` 로 표시되고 실패 호스트가 로그에 남는다. `deploymentStep` 값은 별도 파라미터가 아니라 실행 중인 Jenkins Job 이름(`env.JOB_BASE_NAME`)을 그대로 쓴다.

## 파라미터

| 파라미터 | 예시 | 설명 |
| :--- | :--- | :--- |
| `loc` | `ich` | Agent 위치 (다른 Jenkinsfile 과 동일한 고정 이름) |
| `target_type` | `linux` | 대상 종류 (linux \| windows \| esxi \| redfish) |
| `inventory_json` | `[{"hostname":"linux-dev-01","service_ip":"10.100.64.169"}]` | 대상 호스트 배열 |
| `callbackUrl` | `http://<portal-host>:<port>` | 포털 base URL. `/api/jenkins/logical/server/deployment/step` 을 붙여 호출 |

## Jenkins Script Path

`Day2_Guide/playbook/patterns/runner-master-portal-callback/Jenkinsfile`

## 관리자 준비사항

| 항목 | 상태 | 설명 |
| :--- | :--- | :--- |
| Jenkins job 등록 | ✅ 완료 | `example-provisioning-portal-notify`, GitLab(`root/infra-automation-jenkins-ansible`, `main`) SCM, HTTPS + `root` 크리덴셜 |
| `http_request` / `pipeline-utility-steps` 플러그인 | ✅ 이미 설치됨 | 포털 API 호출(`httpRequest`)과 JSON 처리(`readJSON`/`writeJSON`)에 사용 |
| 전역 Shared Library GitLab 인증 | ✅ 해결됨 | `jenkins-shared-lib` 크리덴셜을 `root`로, Default version을 `main`으로 수정. 이 Jenkins 전체 파이프라인에 영향 있던 문제라 다른 job들도 같이 풀림 |
| `callbackUrl` 실제 값 | ⚠️ 매 빌드 입력 필요 | 코드에 하드코딩하지 않음 — Build with Parameters 할 때마다 직접 입력 |
| Ansible 실행 검증 | ✅ 확인됨 | 실제 빌드에서 `Run Ansible` 정상 동작 확인. 기본 `inventory_json`(`linux-dev-01`)은 가짜 데모 IP라 실패하는 게 정상이며, 이때 `Update Deployment Step`이 스킵되는 것도 확인됨 |
| 포털 실제 성공 케이스 | ❌ 미확인 | 살아있는 실제 호스트 + 실제 `callbackUrl` 없이는 끝까지(포털 응답까지) 확인 불가 |
