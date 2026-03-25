# Playbook 작성 가이드

## 기본 구조

```yaml
- name: 작업명
  hosts: all
  gather_facts: true/false
  connection: ssh/winrm/local

  vars_files:
    - "{{ lookup('env', 'REPO_ROOT') }}/vault/타입.yml"

  tasks:
    - name: 작업 실행
      ...
```

## 서버 타입별 기준

| 타입 | connection | gather_facts |
|------|-----------|--------------|
| linux | ssh | true (운영) / false (OS 설치 전) |
| windows | winrm | true (운영) / false (OS 설치 전) |
| esxi | ssh | true (운영) / false (OS 설치 전) |
| redfish | local | false — BMC 접속이므로 OS Fact 수집 불가 |

## hostvars 참조

```yaml
# hostname 있음 (linux/windows/esxi)
# inventory_hostname = hostname 값 (예: WEB-01)
hostvars[inventory_hostname]['ansible_host']   # 실제 접속 IP
hostvars[inventory_hostname]['service_ip']     # 포털 후속 Job 연계용
hostvars[inventory_hostname]['os_hostname']    # OS 내부에 적용할 hostname

# hostname 없음 (redfish)
# inventory_hostname = ip 값
hostvars[inventory_hostname]['vendor']         # BMC 벤더
hostvars[inventory_hostname]['os_hostname']    # OS 내부에 적용할 hostname
hostvars[inventory_hostname]['firmware_version'] # 펌웨어 버전
```
