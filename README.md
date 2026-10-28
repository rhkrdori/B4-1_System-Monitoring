# B4-1 System Monitoring

Codyssey 4-1 미션 "컴퓨터가 알아서 자기 상태를 점검하게 만들기" 산출물.

WSL2 Ubuntu 26.04 환경에서 SSH·방화벽을 설정하고 계정·그룹·디렉토리 권한을 구성함. 이후 제공된 agent-app을 실행하고, 앱 상태를 매분 자동 점검하는 `monitor.sh`를 cron에 등록함.

## 폴더 구성

| 경로 | 내용 |
|---|---|
| [수행내역서.md](수행내역서.md) | 단계별 명령, 실행 결과, 증거 8개, 트러블슈팅, 배운 점 |
| [scripts/monitor.sh](scripts/monitor.sh) | 상태 점검 스크립트 사본 (원본: `/home/agent-admin/agent-app/bin/monitor.sh`) |
| [images/](images/) | 증거 캡처 (파일명 = 단계 번호) |

## monitor.sh 요약
- 프로세스와 포트 15034 점검, 실패 시 `exit 1`
- 방화벽 비활성 또는 CPU>20% / MEM>10% / DISK>80% 시 `[WARNING]` 출력 (종료하지 않음)
- `/var/log/agent-app/monitor.log`에 `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%` 형식으로 기록
- 로그 10MB 초과 시 로테이션 (최대 10개 유지)
- agent-admin crontab: `* * * * *` (매분 실행)
