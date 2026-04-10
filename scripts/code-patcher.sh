#!/bin/bash
# Self-Evolving Agent - 代码热修补工具 (Code Patcher)
# 支持运行时代码修改、补丁应用和回滚、历史管理

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
PATCH_DIR="$WORKSPACE/self-improving/patches"
HISTORY_DIR="$PATCH_DIR/history"
BACKUP_DIR="$PATCH_DIR/backups"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 初始化目录
mkdir -p "$PATCH_DIR" "$HISTORY_DIR" "$BACKUP_DIR"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

show_help() {
    echo "使用方法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  apply <目标文件> <补丁文件>   - 应用补丁并备份原文件"
    echo "  rollback <目标文件>           - 回滚最近一次的修改"
    echo "  history <目标文件>            - 查看文件的修改历史"
    echo "  list                        - 列出所有已应用的补丁"
    echo "  help                        - 显示此帮助信息"
}

# 应用补丁
apply_patch() {
    local target_file="$1"
    local patch_file="$2"
    
    if [ ! -f "$target_file" ]; then
        log_error "目标文件不存在: $target_file"
        exit 1
    fi
    
    if [ ! -f "$patch_file" ]; then
        log_error "补丁文件不存在: $patch_file"
        exit 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local target_basename=$(basename "$target_file")
    local backup_file="$BACKUP_DIR/${target_basename}_${timestamp}.bak"
    local history_log="$HISTORY_DIR/${target_basename}.log"
    
    # 备份原文件
    cp "$target_file" "$backup_file"
    log_info "已备份原文件至: $backup_file"
    
    # 尝试应用补丁 (这里使用简单的替换逻辑，实际中可使用 patch 命令)
    # 这里我们使用通用的 patch 命令
    if patch -p1 -i "$patch_file" "$target_file"; then
        # 记录历史
        echo "[$timestamp] APPLY: $patch_file -> $target_file (Backup: $backup_file)" >> "$history_log"
        log_success "补丁应用成功: $target_file"
        
        # 记录全局历史
        echo "[$timestamp] $target_file" >> "$PATCH_DIR/applied_patches.list"
    else
        log_error "补丁应用失败，正在恢复原文件..."
        cp "$backup_file" "$target_file"
        log_info "原文件已恢复"
        exit 1
    fi
}

# 回滚最近一次修改
rollback_patch() {
    local target_file="$1"
    local target_basename=$(basename "$target_file")
    local history_log="$HISTORY_DIR/${target_basename}.log"
    
    if [ ! -f "$history_log" ]; then
        log_error "没有找到该文件的历史记录: $target_file"
        exit 1
    fi
    
    # 获取最后一次备份文件路径
    local last_action=$(tail -n 1 "$history_log")
    if [[ ! "$last_action" == *"APPLY"* ]]; then
        log_error "最后一次操作不是 APPLY，无法回滚"
        exit 1
    fi
    
    local backup_file=$(echo "$last_action" | grep -o 'Backup: .*' | cut -d' ' -f2 | tr -d ')')
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "找不到备份文件: $backup_file"
        exit 1
    fi
    
    # 恢复文件
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$backup_file" "$target_file"
    echo "[$timestamp] ROLLBACK: Restored from $backup_file" >> "$history_log"
    log_success "已回滚至版本: $backup_file"
}

# 查看历史
show_history() {
    local target_file="$1"
    local target_basename=$(basename "$target_file")
    local history_log="$HISTORY_DIR/${target_basename}.log"
    
    if [ ! -f "$history_log" ]; then
        log_warning "没有找到该文件的历史记录: $target_file"
        return 0
    fi
    
    echo "文件 $target_file 的修改历史:"
    cat "$history_log"
}

# 列出所有补丁
list_patches() {
    if [ ! -f "$PATCH_DIR/applied_patches.list" ]; then
        log_warning "尚未应用任何补丁"
        return 0
    fi
    
    echo "已应用的补丁列表:"
    cat "$PATCH_DIR/applied_patches.list"
}

# 主逻辑
case "$1" in
    apply)
        if [ -z "$2" ] || [ -z "$3" ]; then
            log_error "参数错误。用法: $0 apply <目标文件> <补丁文件>"
            exit 1
        fi
        apply_patch "$2" "$3"
        ;;
    rollback)
        if [ -z "$2" ]; then
            log_error "参数错误。用法: $0 rollback <目标文件>"
            exit 1
        fi
        rollback_patch "$2"
        ;;
    history)
        if [ -z "$2" ]; then
            log_error "参数错误。用法: $0 history <目标文件>"
            exit 1
        fi
        show_history "$2"
        ;;
    list)
        list_patches
        ;;
    help|*)
        show_help
        ;;
esac

exit 0