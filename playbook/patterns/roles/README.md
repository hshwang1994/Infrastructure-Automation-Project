# patterns/roles — Role 디렉토리 구조

Ansible role 의 표준 디렉토리 레이아웃을 보여주는 최소 예시.

## 구조

```
roles/
├── site.yml                            roles 리스트만 선언
└── roles/
    └── welcome/
        ├── tasks/main.yml              실제 task
        ├── defaults/main.yml           변수 기본값
        └── handlers/main.yml           notify 로 호출되는 핸들러
```

site.yml 은 `roles: [welcome]` 한 줄로 끝나고, 실제 동작은 `roles/welcome/tasks/main.yml` 에 들어 있다.

## 언제 쓰나

- 한 묶음의 task 를 **여러 playbook 에서 재사용**할 때
- 변수 기본값 (`defaults/`) 과 task 본체 (`tasks/`) 를 분리해서 **호출하는 쪽이 일부 변수만 덮어쓸 수 있게** 하고 싶을 때
- 템플릿 (`templates/`) / 파일 (`files/`) / 핸들러 (`handlers/`) 를 한 디렉토리에 묶어두고 싶을 때

## 실제 작업에서 같은 패턴 보기

[`tasks/linux/baseline/`](../../tasks/linux/baseline/) — chrony + motd 두 role 을 적용하는 baseline 구성 작업.
