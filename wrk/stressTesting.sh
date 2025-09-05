#!/bin/bash

# 從命令列參數獲取 name
if [ -z "$1" ]; then
    echo "Error: Please provide a name parameter (e.g., --name=healthCheck)"
    exit 1
fi

# 提取 name 參數
NAME="${1#--name=}"
if [ -z "$NAME" ]; then
    echo "Error: Name parameter cannot be empty"
    exit 1
fi

# 壓力測試配置
URL="http://localhost:8080"  # API 端點
DURATION="30s"              # 每次測試持續時間
THREADS=(4 8)               # 執行緒數（M3 晶片建議 4-16）
CONNECTIONS=(50 100 200 500 1000)  # 連線數遞增
SCRIPT="${NAME}.lua"        # 根據 name 動態設定 Lua 腳本
OUTPUT_DIR="${NAME}_results"  # 根據 name 動態設定輸出目錄
SUMMARY_FILE="summary.csv"  # 總結報告檔案

# 檢查 wrk 是否已安裝
if ! command -v wrk &> /dev/null; then
    echo "Error: wrk is not installed. Please install wrk first."
    exit 1
fi

# 檢查 Lua 腳本是否存在
if [ ! -f "$SCRIPT" ]; then
    echo "Error: $SCRIPT not found."
    exit 1
fi

# 創建輸出目錄
mkdir -p "$OUTPUT_DIR"

# 初始化 CSV 總結檔案
echo "Threads,Connections,Requests/sec,Latency_Avg(ms),Latency_Stdev(ms),Latency_Max(ms),Latency_99%(ms),Transfer/sec,Errors" > "$OUTPUT_DIR/$SUMMARY_FILE"

# 執行壓力測試
for THREAD in "${THREADS[@]}"; do
    for CONNS in "${CONNECTIONS[@]}"; do
        echo "Running test with $THREAD threads and $CONNS connections..."
        OUTPUT_FILE="$OUTPUT_DIR/results_${THREAD}_${CONNS}.txt"
        
        # 執行 wrk 測試並儲存結果，加入 --name=XXX
        wrk -t$THREAD -c$CONNS -d$DURATION -s "$SCRIPT" --latency --timeout 2s "$URL" > "$OUTPUT_FILE"
        
        # 提取關鍵指標
        REQUESTS_PER_SEC=$(grep "Requests/sec" "$OUTPUT_FILE" | awk '{print $2}')
        LATENCY_AVG=$(grep "Latency" "$OUTPUT_FILE" | head -1 | awk '{print $2}' | sed 's/ms//')
        LATENCY_STDEV=$(grep "Latency" "$OUTPUT_FILE" | head -1 | awk '{print $3}' | sed 's/ms//')
        LATENCY_MAX=$(grep "Latency" "$OUTPUT_FILE" | head -1 | awk '{print $4}' | sed 's/ms//')
        LATENCY_99=$(grep "99%" "$OUTPUT_FILE" | awk '{print $2}' | sed 's/ms//')
        TRANSFER_PER_SEC=$(grep "Transfer/sec" "$OUTPUT_FILE" | awk '{print $2}')
        ERRORS=$(grep "Socket errors\|Non-2xx" "$OUTPUT_FILE" | awk '{print $NF}' | paste -sd+ - | bc || echo "0")
        
        # 將指標寫入 CSV
        echo "$THREAD,$CONNS,$REQUESTS_PER_SEC,$LATENCY_AVG,$LATENCY_STDEV,$LATENCY_MAX,$LATENCY_99,$TRANSFER_PER_SEC,$ERRORS" >> "$OUTPUT_DIR/$SUMMARY_FILE"
        
        echo "Results saved to $OUTPUT_FILE"
    done
done

echo "All tests completed. Summary report saved to $OUTPUT_DIR/$SUMMARY_FILE"