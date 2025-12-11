#!/bin/bash

# =========================================
# GGML AI Services Manager for DGX Spark
# =========================================
# 
# If you get "model is private" errors, you may need to:
# 1. Login to HuggingFace: huggingface-cli login
# 2. Or set: export HF_TOKEN=your_token_here
#
# To customize models, edit the SERVICES array below.
# =========================================

# Configuration
LLAMA_SERVER=~/ggml-org/llama.cpp/build-cuda/bin/llama-server
WHISPER_SERVER=~/ggml-org/whisper.cpp/build-cuda/bin/whisper-server
WHISPER_MODEL="$HOME/ggml-org/whisper.cpp/models/ggml-base.en.bin"
LOG_DIR=~/ggml-logs
mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service definitions: name|port|command
# Using verified PUBLIC models from HuggingFace
declare -A SERVICES
SERVICES=(
    ["1_embeddings"]="8021|Embeddings (Nomic)|$LLAMA_SERVER -hf nomic-ai/nomic-embed-text-v1.5-GGUF --port 8021 --host 0.0.0.0 --embedding -ngl 99 --no-mmap"
    ["2_fim"]="8022|Code Completion FIM (Qwen2.5-Coder)|$LLAMA_SERVER -hf Qwen/Qwen2.5-Coder-7B-Instruct-GGUF --port 8022 --host 0.0.0.0 --ctx-size 32768 -ngl 99 --no-mmap"
    ["3_chat"]="8023|Chat/Tools (GPT-OSS 120B)|$LLAMA_SERVER -hf ggml-org/gpt-oss-120b-GGUF --port 8023 --host 0.0.0.0 --ctx-size 131072 -np 8 --jinja -ub 2048 -b 2048 -ngl 99 --no-mmap"
    ["4_vision"]="8024|Vision (Qwen2-VL 7B)|$LLAMA_SERVER -hf Qwen/Qwen2-VL-7B-Instruct-GGUF --port 8024 --host 0.0.0.0 --ctx-size 8192 -ngl 99 --no-mmap"
    ["5_stt"]="8025|Speech-to-Text (Whisper)|$WHISPER_SERVER -m $WHISPER_MODEL --port 8025 --host 0.0.0.0"
)

# Check if a port is in use
is_port_running() {
    local port=$1
    netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "
}

# Get service info
get_port() { echo "$1" | cut -d'|' -f1; }
get_name() { echo "$1" | cut -d'|' -f2; }
get_cmd() { echo "$1" | cut -d'|' -f3-; }

# Display status of all services
show_status() {
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    GGML Services Status${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
    
    printf "  %-4s %-35s %-8s %s\n" "No." "Service" "Port" "Status"
    echo "  ─────────────────────────────────────────────────────────────"
    
    for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
        local info="${SERVICES[$key]}"
        local port=$(get_port "$info")
        local name=$(get_name "$info")
        local num="${key:0:1}"
        
        if is_port_running "$port"; then
            printf "  ${GREEN}%-4s %-35s %-8s [RUNNING]${NC}\n" "[$num]" "$name" ":$port"
        else
            printf "  ${RED}%-4s %-35s %-8s [STOPPED]${NC}\n" "[$num]" "$name" ":$port"
        fi
    done
    echo ""
}

# Start a single service
start_service() {
    local key=$1
    local info="${SERVICES[$key]}"
    local port=$(get_port "$info")
    local name=$(get_name "$info")
    local cmd=$(get_cmd "$info")
    
    if is_port_running "$port"; then
        echo -e "  ${YELLOW}⚠ $name is already running on port $port${NC}"
        return 1
    fi
    
    # Special check for whisper model
    if [[ "$key" == "5_stt" ]] && [[ ! -f "$WHISPER_MODEL" ]]; then
        echo -e "  ${RED}✗ Whisper model not found: $WHISPER_MODEL${NC}"
        echo -e "  ${YELLOW}  Download it with:${NC}"
        echo -e "  ${YELLOW}  cd ~/ggml-org/whisper.cpp && bash ./models/download-ggml-model.sh base.en${NC}"
        return 1
    fi
    
    echo -e "  ${BLUE}Starting $name on port $port...${NC}"
    local logfile="$LOG_DIR/service-$port.log"
    
    # Start service in background with logging
    nohup bash -c "$cmd" > "$logfile" 2>&1 &
    
    # Wait a moment and verify
    sleep 2
    if is_port_running "$port"; then
        echo -e "  ${GREEN}✓ $name started successfully${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to start $name - check $logfile${NC}"
        return 1
    fi
}

# Stop a single service
stop_service() {
    local key=$1
    local info="${SERVICES[$key]}"
    local port=$(get_port "$info")
    local name=$(get_name "$info")
    
    if ! is_port_running "$port"; then
        echo -e "  ${YELLOW}⚠ $name is not running${NC}"
        return 1
    fi
    
    echo -e "  ${BLUE}Stopping $name on port $port...${NC}"
    
    # Find and kill process on this port
    local pid=$(lsof -ti:$port 2>/dev/null || fuser $port/tcp 2>/dev/null | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null
        sleep 1
        # Force kill if still running
        if is_port_running "$port"; then
            kill -9 $pid 2>/dev/null
            sleep 1
        fi
    fi
    
    if ! is_port_running "$port"; then
        echo -e "  ${GREEN}✓ $name stopped${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to stop $name${NC}"
        return 1
    fi
}

# Interactive menu for selecting services
select_services() {
    local action=$1
    local selected=()
    
    while true; do
        clear
        echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}              Select Services to $action${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
        
        printf "  %-4s %-35s %-8s %s\n" "No." "Service" "Port" "Status"
        echo "  ─────────────────────────────────────────────────────────────"
        
        for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
            local info="${SERVICES[$key]}"
            local port=$(get_port "$info")
            local name=$(get_name "$info")
            local num="${key:0:1}"
            
            # Check if selected
            local mark=" "
            for s in "${selected[@]}"; do
                if [ "$s" == "$key" ]; then
                    mark="${GREEN}✓${NC}"
                    break
                fi
            done
            
            if is_port_running "$port"; then
                printf "  [%b] ${GREEN}%-3s %-35s %-8s [RUNNING]${NC}\n" "$mark" "$num" "$name" ":$port"
            else
                printf "  [%b] ${RED}%-3s %-35s %-8s [STOPPED]${NC}\n" "$mark" "$num" "$name" ":$port"
            fi
        done
        
        echo ""
        echo -e "  ${YELLOW}Commands:${NC}"
        echo "    1-5  Toggle service selection"
        echo "    a    Select all"
        echo "    n    Select none"
        echo "    d    Done - execute $action"
        echo "    q    Cancel and go back"
        echo ""
        read -p "  Enter choice: " choice
        
        case $choice in
            [1-5])
                local key="${choice}_"
                for k in "${!SERVICES[@]}"; do
                    if [[ "$k" == ${choice}_* ]]; then
                        key="$k"
                        break
                    fi
                done
                
                # Toggle selection
                local found=false
                local new_selected=()
                for s in "${selected[@]}"; do
                    if [ "$s" == "$key" ]; then
                        found=true
                    else
                        new_selected+=("$s")
                    fi
                done
                
                if [ "$found" = false ]; then
                    new_selected+=("$key")
                fi
                selected=("${new_selected[@]}")
                ;;
            a|A)
                selected=()
                for key in "${!SERVICES[@]}"; do
                    selected+=("$key")
                done
                ;;
            n|N)
                selected=()
                ;;
            d|D)
                if [ ${#selected[@]} -eq 0 ]; then
                    echo -e "\n  ${YELLOW}No services selected${NC}"
                    sleep 1
                else
                    return 0
                fi
                ;;
            q|Q)
                selected=()
                return 1
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        clear
        show_status
        
        echo -e "${YELLOW}  Options:${NC}"
        echo "    1) Start services"
        echo "    2) Stop services"
        echo "    3) Restart services"
        echo "    4) Start ALL services"
        echo "    5) Stop ALL services"
        echo "    6) View logs"
        echo "    7) Refresh status"
        echo "    q) Quit"
        echo ""
        read -p "  Enter choice: " choice
        
        case $choice in
            1)
                select_services "START"
                if [ $? -eq 0 ] && [ ${#selected[@]} -gt 0 ]; then
                    echo ""
                    for key in $(echo "${selected[@]}" | tr ' ' '\n' | sort); do
                        start_service "$key"
                    done
                    echo ""
                    read -p "  Press Enter to continue..."
                fi
                ;;
            2)
                select_services "STOP"
                if [ $? -eq 0 ] && [ ${#selected[@]} -gt 0 ]; then
                    echo ""
                    for key in $(echo "${selected[@]}" | tr ' ' '\n' | sort); do
                        stop_service "$key"
                    done
                    echo ""
                    read -p "  Press Enter to continue..."
                fi
                ;;
            3)
                select_services "RESTART"
                if [ $? -eq 0 ] && [ ${#selected[@]} -gt 0 ]; then
                    echo ""
                    for key in $(echo "${selected[@]}" | tr ' ' '\n' | sort); do
                        stop_service "$key"
                    done
                    sleep 2
                    for key in $(echo "${selected[@]}" | tr ' ' '\n' | sort); do
                        start_service "$key"
                    done
                    echo ""
                    read -p "  Press Enter to continue..."
                fi
                ;;
            4)
                echo ""
                for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
                    start_service "$key"
                done
                echo ""
                read -p "  Press Enter to continue..."
                ;;
            5)
                echo ""
                for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort -r); do
                    stop_service "$key"
                done
                echo ""
                read -p "  Press Enter to continue..."
                ;;
            6)
                echo ""
                echo -e "  ${CYAN}Available logs:${NC}"
                ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "  No logs found"
                echo ""
                read -p "  Enter port number to view log (or Enter to skip): " logport
                if [ -n "$logport" ] && [ -f "$LOG_DIR/service-$logport.log" ]; then
                    less "$LOG_DIR/service-$logport.log"
                fi
                ;;
            7)
                # Just refresh
                ;;
            q|Q)
                echo -e "\n  ${GREEN}Goodbye!${NC}\n"
                exit 0
                ;;
        esac
    done
}

# Command line arguments
case "${1:-}" in
    --start-all)
        echo -e "\n${CYAN}Starting all GGML services...${NC}\n"
        for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
            start_service "$key"
        done
        echo ""
        ;;
    --stop-all)
        echo -e "\n${CYAN}Stopping all GGML services...${NC}\n"
        for key in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort -r); do
            stop_service "$key"
        done
        echo ""
        ;;
    --status)
        show_status
        ;;
    --help|-h)
        echo ""
        echo "GGML AI Services Manager for DGX Spark"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (none)       Interactive mode"
        echo "  --start-all  Start all services"
        echo "  --stop-all   Stop all services"
        echo "  --status     Show service status"
        echo "  --models     Show configured models"
        echo "  --help       Show this help"
        echo ""
        echo "Models used (edit script to customize):"
        echo "  Embeddings: nomic-ai/nomic-embed-text-v1.5-GGUF"
        echo "  Code/FIM:   Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
        echo "  Chat:       ggml-org/gpt-oss-120b-GGUF"
        echo "  Vision:     Qwen/Qwen2-VL-7B-Instruct-GGUF"
        echo "  STT:        whisper base.en"
        echo ""
        echo "If you get 'model is private' errors:"
        echo "  export HF_TOKEN=your_huggingface_token"
        echo "  # or run: huggingface-cli login"
        echo ""
        ;;
    --models)
        echo ""
        echo "Configured Models:"
        echo "─────────────────────────────────────────────────────────────"
        echo "  [8021] Embeddings:  nomic-ai/nomic-embed-text-v1.5-GGUF"
        echo "  [8022] Code/FIM:    Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
        echo "  [8023] Chat:        ggml-org/gpt-oss-120b-GGUF"
        echo "  [8024] Vision:      Qwen/Qwen2-VL-7B-Instruct-GGUF"
        echo "  [8025] STT:         whisper base.en ($WHISPER_MODEL)"
        echo ""
        echo "Edit this script to change models."
        echo ""
        ;;
    *)
        main_menu
        ;;
esac
