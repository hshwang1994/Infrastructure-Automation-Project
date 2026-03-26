# Log Parse Sample

Ansible 로그 파싱 테스트용 샘플.
Jenkins 콘솔 로그에서 TASK 절과 PLAY RECAP 절의 상태값을 파싱할 때 사용한다.

## 디렉토리 구조

```
log-parse-sample/
├── README.md
├── linux/
│   ├── Jenkinsfile
│   ├── status-ok-changed-skipped.yml     ← 상태 유도: ok, changed, skipped
│   ├── status-fail-rescue-ignore.yml     ← 상태 유도: rescued, ignored
│   ├── status-mixed.yml                  ← 상태 유도: 6가지 전부
│   ├── memory-info.yml                   ← 수집: 메모리 + host별 분기
│   ├── network-info.yml                  ← 수집: 네트워크 + host별 분기
│   ├── host-condition.yml                ← 분기: host별 상태 분기
│   └── force-fail.yml                    ← 실패: 의도적 rc≠0
└── windows/
    └── (동일 구조, WinRM 모듈 사용)
```

## Playbook 역할 분리

| 계열 | 파일 | 유도 상태 |
|------|------|----------|
| 상태 유도 | status-ok-changed-skipped | ok, changed, skipped |
| 상태 유도 | status-fail-rescue-ignore | rescued, ignored |
| 상태 유도 | status-mixed | 6가지 전부 |
| 수집 | memory-info | ok + host별 changed/skipped |
| 수집 | network-info | ok + host별 changed/skipped |
| 분기 | host-condition | host별 5가지 상태 |
| 실패 | force-fail | rc≠0 (suffix=1 host만 실패) |

## Stage 구성 (총 20회 실행)

### Stage 1: Status Induction — 7회

| # | Playbook | run_id |
|---|----------|--------|
| 1 | status-ok-changed-skipped | 1 |
| 2 | status-fail-rescue-ignore | 1 |
| 3 | status-mixed | 1 |
| 4 | status-ok-changed-skipped | 2 |
| 5 | status-fail-rescue-ignore | 2 |
| 6 | status-mixed | 2 |
| 7 | host-condition | 1 |

### Stage 2: Collection & Repeat — 6회

| # | Playbook | run_id |
|---|----------|--------|
| 1 | memory-info | 1 |
| 2 | memory-info | 2 |
| 3 | network-info | 1 |
| 4 | network-info | 2 |
| 5 | host-condition | 2 |
| 6 | status-mixed | 3 |

### Stage 3: Final Validation — 7회

| # | Playbook | run_id |
|---|----------|--------|
| 1 | host-condition | 3 |
| 2 | memory-info | 3 |
| 3 | network-info | 3 |
| 4 | status-ok-changed-skipped | 3 |
| 5 | status-fail-rescue-ignore | 3 |
| 6 | status-mixed | 4 |
| 7 | force-fail | 1 |

## 파싱 키

```
stage + playbook + run_id + host + task → status
```

### Jenkins 콘솔 마커

각 playbook 실행 전후로 마커가 출력된다:

```
[START] stage=Status Induction playbook=status-ok-changed-skipped run_id=1
PLAY [log-parse / status-ok-changed-skipped [run=1]] ******
...
PLAY RECAP ******
[END] stage=Status Induction playbook=status-ok-changed-skipped run_id=1
```

### run_id 전달 방식

Jenkinsfile에서 `withEnv(["RUN_ID=N"])` 으로 환경변수를 설정하고,
Playbook에서 `lookup('env', 'RUN_ID')` 으로 읽어서 play name에 포함한다.
`ansiblePlaybook()` 호출 형태는 기존 컨벤션(installation, playbook, inventory, colorized)과 동일하게 유지한다.

## host별 분기

hostname 끝 숫자로 분기한다:

| 끝 숫자 | host-condition 결과 | memory-info | network-info |
|---------|-------------------|-------------|-------------|
| 1 | ok | ok | changed (DNS) |
| 2 | changed | changed (reviewed) | ok |
| 3 | skipped (전부) | skipped (meminfo) | ok |
| 4 | ignored | ok | skipped (routing) |
| 5 | rescued | ok | ok |

### 분기 방식 전환 가이드

기본은 hostname 끝 숫자 추출 방식이다:
```yaml
_host_num: "{{ (inventory_hostname | regex_search('(\\d+)$', '\\1') | default(['0'], true) | first) | int }}"
```

hostname 네이밍이 다른 환경에서는 `_host_num` 변수만 수정하면 된다:
```yaml
# hostvars 기반 (포털에서 condition_id 필드를 보내는 경우)
_host_num: "{{ hostvars[inventory_hostname]['condition_id'] | default(0) | int }}"

# group_vars 기반 (인벤토리 그룹으로 분기하는 경우)
# group_vars/suffix1.yml → condition_id: 1
_host_num: "{{ condition_id | default(0) | int }}"
```

## 기대 PLAY RECAP

### host-condition.yml (5대 실행 시)

```
LNX-01 : ok=2  changed=0  unreachable=0  failed=0  skipped=3  rescued=0  ignored=0
LNX-02 : ok=1  changed=1  unreachable=0  failed=0  skipped=3  rescued=0  ignored=0
LNX-03 : ok=1  changed=0  unreachable=0  failed=0  skipped=4  rescued=0  ignored=0
LNX-04 : ok=1  changed=0  unreachable=0  failed=0  skipped=3  rescued=0  ignored=1
LNX-05 : ok=2  changed=0  unreachable=0  failed=0  skipped=3  rescued=1  ignored=0
```

### force-fail.yml (5대 실행 시)

```
LNX-01 : ok=1  changed=0  unreachable=0  failed=1  skipped=0  rescued=0  ignored=0
LNX-02 : ok=1  changed=0  unreachable=0  failed=0  skipped=1  rescued=0  ignored=0
LNX-03 : ok=1  changed=0  unreachable=0  failed=0  skipped=1  rescued=0  ignored=0
LNX-04 : ok=1  changed=0  unreachable=0  failed=0  skipped=1  rescued=0  ignored=0
LNX-05 : ok=1  changed=0  unreachable=0  failed=0  skipped=1  rescued=0  ignored=0
```

## 실행 방법

Jenkins에서 파라미터 입력:
- **loc**: Agent 위치
- **target_type**: `linux` 또는 `windows`
- **inventory_json**: 5대 이상 권장

```json
[
  {"bmc_ip":"","service_ip":"10.0.2.1","hostname":"LNX-01","vendor":""},
  {"bmc_ip":"","service_ip":"10.0.2.2","hostname":"LNX-02","vendor":""},
  {"bmc_ip":"","service_ip":"10.0.2.3","hostname":"LNX-03","vendor":""},
  {"bmc_ip":"","service_ip":"10.0.2.4","hostname":"LNX-04","vendor":""},
  {"bmc_ip":"","service_ip":"10.0.2.5","hostname":"LNX-05","vendor":""}
]
```

## 주의사항

- **force-fail.yml**: suffix=1 호스트에서 의도적으로 실패한다. Stage 3이 FAILURE로 표시되는 것은 정상이다.
- **안전성**: 모든 task는 읽기 전용이다. 운영 장비에 영향을 주는 작업은 없다.
- **호스트 수**: 5대 미만이면 일부 상태가 나타나지 않을 수 있다. (예: 3대면 suffix 1~3 상태만)
