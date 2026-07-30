# tasks/linux/hostvars-demo — inventory_json 추가 필드 → hostvar

`inventory_json` 에 `hostname` / `service_ip` 외 필드를 더 넣으면, 그 값들이 **호스트마다 따로** ansible hostvar 가 되어 playbook 에서 `{{ 필드명 }}` 으로 바로 쓰인다는 걸 보여주는 데모.

## 어떻게 동작하는가

`inventory/my_inventory.sh` 가 `hostname`(→ `inventory_hostname`) 과 `service_ip`(→ `ansible_host`) 만 특별 취급하고, **나머지 필드는 손대지 않고 그대로 그 호스트의 hostvar 로 통과**시킨다. 그래서 필드를 추가할 때 인벤토리 스크립트도 Jenkinsfile 도 고칠 필요가 없다 — playbook 에서 참조만 하면 된다.

```
inventory_json 항목                         my_inventory.sh 가 만드는 hostvars
─────────────────────────────────────────   ─────────────────────────────────
{                                            "linux-dev-01": {
  "hostname":    "linux-dev-01",      ──┐      "ansible_host": "10.100.64.169",
  "service_ip":  "10.100.64.169",  ────┘      "tier":         "web",
  "tier":        "web",            ──┐        "patch_window": "Sun 02:00"
  "patch_window":"Sun 02:00"       ──┘    }
}
```

`site.yml` 에서:

```yaml
msg: "tier={{ tier }} patch_window={{ patch_window | default('미지정') }}"
when: tier | default('') == 'db'
```

## 보여주는 두 가지 핵심

| 패턴 | 코드 | 언제 |
| :--- | :--- | :--- |
| 직접 참조 | `{{ tier }}` | 모든 호스트가 반드시 갖는 필드 |
| 누락 대비 | `{{ patch_window \| default('미지정') }}` | 일부 호스트만 갖는 선택 필드 |
| 조건 분기 | `when: tier \| default('') == 'db'` | hostvar 값에 따라 task 실행 여부 결정 |

기본 `inventory_json` 의 `linux-dev-02` 는 `patch_window` 를 **일부러 빼 두었다.** `default()` 없이 `{{ patch_window }}` 로 쓰면 그 호스트에서 에러가 나므로, 선택 필드는 항상 `default()` 로 받는 게 안전하다는 걸 보여주기 위함.

## hostvar vs extraVars

| | hostvar (이 데모) | extraVars (`sandbox/userNN/extravars.yml`) |
| :--- | :--- | :--- |
| 범위 | 호스트마다 다른 값 (per-host) | 실행 전체 공통 (global) |
| 출처 | inventory_json → `my_inventory.sh` | Jenkins 파라미터 → `extraVars: [...]` |
| 참조 | `{{ tier }}` (호스트별로 값 다름) | `{{ greeting }}` (모든 호스트 동일) |

호스트마다 달라지는 값(IP, 계층, 패치창…) 은 inventory_json 필드로, 실행 전체에 하나로 적용할 스위치는 extraVars 로 넘긴다.

## 실행

`gather_facts: false` / `connection: local` 이라 컨트롤러(= Jenkins agent) 에서 바로 돈다. **변수 흐름만 확인하는 데모라 타겟 호스트로 SSH 접속하지 않는다** — `inventory_json` 의 IP 가 살아있지 않아도 출력이 나온다.

Jenkins Script Path: `Day2_Guide/playbook/tasks/linux/hostvars-demo/Jenkinsfile`

기본 파라미터 그대로 **Build with Parameters → Build** 하면 두 호스트의 hostvar 출력과 `linux-dev-02`(tier=db) 에서만 추가로 도는 task 를 볼 수 있다.

## 직접 해보기

1. `inventory_json` 에 호스트를 추가하고 `tier` / `patch_window` 외 새 필드(`owner`, `app_version` …) 를 넣어 본다.
2. `site.yml` 에 `{{ 새필드 }}` 참조를 추가해 출력되는지 확인한다.
3. `when:` 조건을 `tier == 'web'` 로 바꿔 실행 대상 호스트가 달라지는지 본다.
