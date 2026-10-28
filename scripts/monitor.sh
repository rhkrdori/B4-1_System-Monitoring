#!/bin/bash
# monitor.sh - agent-app 상태 점검 스크립트

# ===== 설정 =====
# cron은 .bashrc를 읽지 않아서 환경변수가 비어 있어요.
# 값이 없으면 오른쪽 기본값을 써요.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
AGENT_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$AGENT_LOG_DIR/monitor.log"
PROC_PATTERN="agent-app-linux-x86|agent_app.py"

echo "===== agent-app 점검 시작 ====="

# ===== [1] 프로세스 점검 =====
PID=$(pgrep -n -f "$PROC_PATTERN")
if [ -z "$PID" ]; then
    echo "[ERROR] 프로세스를 찾을 수 없음 ($PROC_PATTERN)"
    exit 1
fi
echo "[OK] 프로세스 실행 중 (PID: $PID)"


# ===== [2] 포트 점검 =====
if [ -z "$(ss -tlnH "sport = :$AGENT_PORT")" ]; then
    echo "[ERROR] 포트 $AGENT_PORT 가 LISTEN 상태가 아님"
    exit 1
fi
echo "[OK] 포트 $AGENT_PORT LISTEN 중"

# ===== [3] 방화벽 점검 (문제가 있어도 종료하지 않음) =====
if grep -qi '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null && systemctl is-active --quiet ufw; then
    echo "[OK] 방화벽(UFW) 활성"
else
    echo "[WARNING] 방화벽(UFW)이 비활성 상태"
fi

# ===== [4] 자원 사용량 수집 =====
# CPU: top으로 1초 간격 2번 측정해서 두 번째 값(최근 1초 사용률)을 써요
CPU=$(top -b -n 2 -d 1 -p "$PID" | awk -v p="$PID" '$1 == p { cpu = $9 } END { print cpu }')
# MEM: 전체 메모리 중 이 프로세스가 쓰는 비율
MEM=$(ps -p "$PID" -o %mem= | tr -d ' ')
# DISK: 루트(/) 파티션 사용률, % 기호는 떼고 숫자만
DISK=$(df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }')

echo "[INFO] CPU: ${CPU}% / MEM: ${MEM}% / DISK_USED: ${DISK}%"

# ===== [5] 임계값 점검 =====
CPU_LIMIT=20
MEM_LIMIT=10
DISK_LIMIT=80

# over 값 기준 → 값이 기준보다 크면 참(0) 반환. 소수점 비교라 awk 사용
over() { awk -v v="$1" -v t="$2" 'BEGIN { exit !(v > t) }'; }

over "$CPU"  "$CPU_LIMIT"  && echo "[WARNING] CPU 사용률 ${CPU}% (기준 ${CPU_LIMIT}% 초과)"
over "$MEM"  "$MEM_LIMIT"  && echo "[WARNING] MEM 사용률 ${MEM}% (기준 ${MEM_LIMIT}% 초과)"
over "$DISK" "$DISK_LIMIT" && echo "[WARNING] DISK 사용률 ${DISK}% (기준 ${DISK_LIMIT}% 초과)"

# ===== [6] 로그 기록 (10MB 넘으면 파일 교체, 최대 10개 유지) =====
MAX_SIZE="${LOG_MAX_SIZE:-$((10 * 1024 * 1024))}"   # 10MB (테스트용으로 바꿀 수 있게)
MAX_FILES=10                                         # monitor.log + .1 ~ .9

if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE")" -ge "$MAX_SIZE" ]; then
    rm -f "$LOG_FILE.$((MAX_FILES - 1))"
    for ((i = MAX_FILES - 2; i >= 1; i--)); do
        [ -f "$LOG_FILE.$i" ] && mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
    done
    mv "$LOG_FILE" "$LOG_FILE.1"
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$NOW] PID:$PID CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK}%" >> "$LOG_FILE"
echo "[INFO] 로그 기록 완료: $LOG_FILE"
exit 0
