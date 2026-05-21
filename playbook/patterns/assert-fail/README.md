# patterns/assert-fail — 시작 전에 조건을 검증해서 사고 막기

prod 에 돌려야 할 playbook 을 실수로 dev 에서 돌렸다거나, 필요한 변수를 빼먹고 실행했다거나 — 이런 사고는 **첫 task 에서** 막아두면 좋다. 본 작업이 시작도 안 되니 피해도 없다.

- `assert` 는 "조건이 안 맞으면 멈춰" — **검증** 도구
- `fail` 은 "여기서 무조건 멈춰" — **명시적 중단**

비슷해 보이지만 쓰임이 다르다. assert 는 "조건을 검사하는 보안 카메라" 같고, fail 은 "여기까지 왔으면 끝" 의 brake 같다.

## 동작 흐름

```yaml
- name: env 변수가 비어있지 않은지 검증
  ansible.builtin.assert:
    that:
      - env | length > 0
    fail_msg: "env 가 비어 있음 — -e env=값 으로 넘기세요"

- name: prod 환경 아니면 무조건 중단
  ansible.builtin.fail:
    msg: "이 playbook 은 prod 전용"
  when: env != 'prod'
```

## 직접 돌려보기

같은 playbook 을 네 가지 입력으로 돌려보면 각 단계에서 어떻게 멈추는지 보인다:

```bash
# 1) env 안 줌 → 첫 assert 에서 멈춤
ansible-playbook site.yml

# 2) 허용 안 된 값 → 두 번째 assert 에서 멈춤
ansible-playbook site.yml -e env=production

# 3) 허용된 값이지만 prod 아님 → fail 에서 멈춤
ansible-playbook site.yml -e env=dev

# 4) 전부 통과 — 본 작업으로 진입
ansible-playbook site.yml -e env=prod
```

각 단계마다 어떤 메시지가 어떤 모듈에서 나오는지 비교해보면 assert / fail 의 쓰임이 자연스럽게 잡힌다.

## assert vs fail — 한 줄 차이

| 모듈   | 언제 멈추나                       | 메시지 옵션                |
|:-------|:----------------------------------|:---------------------------|
| assert | `that:` 조건이 거짓일 때만        | `fail_msg` + `success_msg` |
| fail   | task 가 실행되면 무조건           | `msg` (보통 `when:` 과 조합) |

요약: assert = "검증", fail = "분기 후 중단".

## 실제 작업에서 어디 쓰이나

- `tasks/linux/pkg-update/pre.yml` — 루트 파티션 1 GB 이상 여유 검증
- `tasks/linux/pkg-update/post.yml` — 업데이트 후 sshd 가 살아있는지 검증
- `sandbox/` 의 `pre.yml` — RHEL 9 환경인지 검증 (다른 OS 면 본 작업 시작도 안 함)
