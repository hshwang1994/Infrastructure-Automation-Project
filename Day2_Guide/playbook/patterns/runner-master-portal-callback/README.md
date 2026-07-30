# patterns/runner-master-portal-callback — Runner 실행 + Master 전용 포털 배포단계 갱신

`example_action` Role 을 Runner 에서 여러 호스트에 실행하고, 성공하면 Jenkins Master(`built-in`)가 각 호스트의 배포단계를 포털에 기록하는 참조 구현.

## 통신 구조

```
stage('Run Ansible')                       stage('Update Deployment Step')
agent: params.loc                          agent: built-in
┌─────────────────────────┐                ┌─────────────────────────┐
│ inventory_json 의 모든   │   exit code    │ inventory_json 에서      │
│ 호스트에 example_action  │ ─────────────▶ │ hostName 전체 추출       │
│ Role 실행                │                │ 호스트별 포털 API POST   │──▶ Portal
│                          │                │ (최대 3회 재시도)        │
└─────────────────────────┘                └─────────────────────────┘
```

Runner 는 포털과 통신할 수 없는 망이라 포털 API 호출은 하지 않는다. `stage('Run Ansible')` 은 최상위 `agent`(`params.loc`, 이 환경에서는 `git`)를 그대로 쓰고, `stage('Update Deployment Step')` 만 `agent { label 'built-in' }` 로 override 해서 Jenkins Master 에서 돈다.

Ansible 이 0이 아닌 코드로 끝나면 `ansiblePlaybook()` 스텝이 그 자리에서 파이프라인을 실패시켜 `Update Deployment Step` 자체가 실행되지 않는다 — `catchError`/`ignore_errors` 없음.

대상 호스트 SSH 인증은 `vault/linux.yml`(ansible-vault 암호화)의 `ansible_user`/`ansible_password` 로 처리한다 — 다른 `tasks/linux` 작업들과 동일한 방식.

## 다중 호스트 실행

`inventory_json` 배열의 모든 호스트가 `Run Ansible` stage 에서 처리된다(`site.yml` 의 `hosts: all`, 인벤토리는 Agent 의 공용 동적 인벤토리 사용 — 이 저장소 다른 작업들과 동일). 전체 성공해야만 다음 stage 로 넘어가며, Jenkins Master 는 Ansible 실행 결과가 아니라 **원본 `inventory_json` 파라미터**에서 다시 `hostName` 목록을 추출해 포털에 순서대로 전달한다.

호스트 하나라도 포털 API 최종 실패(3회 재시도 소진)하면 빌드는 `UNSTABLE` 로 표시되고 실패 호스트가 로그에 남는다. `deploymentStep` 값은 별도 파라미터가 아니라 실행 중인 Jenkins Job 이름(`env.JOB_BASE_NAME`)을 그대로 쓴다.

## 파라미터

| 파라미터 | 예시 | 설명 |
| :--- | :--- | :--- |
| `loc` | `git` | Ansible 을 실행할 Runner 라벨 (이 환경에서 사용 가능한 라벨) |
| `target_type` | `linux` | 대상 종류 (linux \| windows \| esxi \| redfish) — 인벤토리 스크립트용 |
| `inventory_json` | `[{"hostname":"jm-auto-install-test01","service_ip":"10.100.64.182"}, ...]` | 대상 호스트 배열. 기본값은 실제 호스트 2대 + 접속 불가능한 가짜 호스트 1대(`linux-dev-fail`/`10.100.64.199`) — Ansible 전체 실패(FAILURE) 시 `Update Deployment Step`이 스킵되는 걸 그대로 보여주기 위함 |
| `callbackUrl` | `http://<portal-host>:<port>` | 포털 base URL. `/api/jenkins/logical/server/deployment/step` 을 붙여 호출 |

## Jenkins Script Path

`Day2_Guide/playbook/patterns/runner-master-portal-callback/Jenkinsfile_deployment-step-notify`

(파일명은 이 Jenkins 인스턴스의 기존 관례 `Jenkinsfile_<액션명>` 을 따름)

## 관리자 준비사항

| 항목 | 상태 | 설명 |
| :--- | :--- | :--- |
| Jenkins job 등록 | ✅ 완료 | `example-provisioning-portal-notify`, GitLab(`root/infra-automation-jenkins-ansible`, `main`) SCM, HTTPS + `root` 크리덴셜 |
| `http_request` / `pipeline-utility-steps` 플러그인 | ✅ 이미 설치됨 | 포털 API 호출(`httpRequest`)과 JSON 처리(`readJSON`/`writeJSON`)에 사용 |
| 전역 Shared Library GitLab 인증 | ✅ 해결됨 | `jenkins-shared-lib` 크리덴셜을 `root`로, Default version을 `main`으로 수정. 이 Jenkins 전체 파이프라인에 영향 있던 문제라 다른 job들도 같이 풀림 |
| `vault/linux.yml` 인증정보 | ✅ 갱신됨 | `ansible_user: cloviradmin` 으로 갱신 (GitLab에만 반영, GitHub 미반영) |
| `callbackUrl` 실제 값 | ⚠️ 매 빌드 입력 필요 | 코드에 하드코딩하지 않음 — Build with Parameters 할 때마다 직접 입력 |
| 실제 호스트 대상 Ansible 실행 | ✅ 확인됨 | 실 호스트 `jm-auto-install-test01`(10.100.64.182), `jm-auto-install-test02`(10.100.64.183) 대상 빌드에서 `ok=2`, 실패 0 확인 |
| 포털 API 갱신 + 재시도 + UNSTABLE 처리 | ✅ 확인됨 | 위 실 호스트 빌드에서 `callbackUrl` 미입력 시 `MalformedURLException` → 3회 재시도 → 호스트별 실패 로그 → 빌드 `UNSTABLE` 까지 실제로 확인됨 |
| 포털 실제 성공(200 + success:true) 케이스 | ❌ 미확인 | 실제 유효한 `callbackUrl` 이 있어야만 확인 가능 |
