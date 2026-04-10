#!/bin/bash
#==========================================
# 安全沙箱验证器 - Sandbox Validator
# 用于代码执行前的安全检查
#==========================================

set -euo pipefail

# 配置
WORKSPACE="${HOME}/.openclaw/workspace"
SANDBOX_DIR="${WORKSPACE}/.sandbox"
LOG_DIR="${WORKSPACE}/logs/sandbox"
DANGEROUS_PATTERNS=(
    "rm\s+-rf\s+/{bin|boot|dev|etc|lib|proc|root|sys|usr}"
    "curl\s*\|\s*sh"
    "wget\s*\|\s*sh"
    ":(){:|:&};:"  # Fork bomb
    "chmod\s+-R\s+777\s+/"
    "dd\s+if=/dev/zero\s+of=/dev/sd"
    "mkfs\."
    ">\s*/proc/"
    ">\s*/sys/"
    ">\s*/dev/"
)

# 创建必要的目录
mkdir -p "${SANSHOTS_DIR}" "${LOG_DIR}"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SANDBOX] $*" | tee -a "${LOG_DIR}/sandbox.log"
}

# 保存快照
save_snapshot() {
    local label="$1"
    local snapshot_dir="${SANDBOX_DIR}/${label}"
    mkdir -p "${snapshot_dir}"
    
    # 记录关键文件和目录状态
    {
        echo "=== Snapshot: ${label} ==="
        echo "Time: $(date)"
        echo ""
        echo "=== OpenClaw Files ==="
        find "${WORKSPACE}" -type f -name "*.json" -o -name "*.md" 2>/dev/null | head -50
        echo ""
        echo "=== Disk Usage ==="
        df -h "${WORKSPACE}" 2>/dev/null || true
    } > "${snapshot_dir}/manifest.txt"
    
    echo "${snapshot_dir}"
}

# 静态代码分析
analyze_danger() {
    local script="$1"
    local violations=()
    
    if [[ ! -f "$script" ]]; then
        log "❌ 脚本不存在: $script"
        return 1
    fi
    
    # 读取脚本内容
    local content
    content=$(cat "$script")
    
    # 检查危险模式
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if echo "$content" | grep -Eiq "$pattern"; then
            violations+=("检测到危险模式: $pattern")
        fi
    done
    
    # 检查 sudo/root 权限操作
    if echo "$content" | grep -Eq "^\s*sudo\s+" || echo "$content" | grep -Eq "chmod\s+[47]777"; then
        violations+=("检测到权限提升操作")
    fi
    
    # 检查网络下载执行
    if echo "$content" | grep -Eq "(wget|curl).*\|\s*(bash|sh|zsh)"; then
        violations+=("检测到远程代码执行")
    fi
    
    # 返回结果
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "❌ 安全检查失败:"
        for v in "${violations[@]}"; do
            echo "   - $v"
        done
        return 1
    fi
    
    echo "✅ 安全检查通过"
    return 0
}

# 备份当前状态
backup_state() {
    local backup_dir="${SANDBOX_DIR}/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${backup_dir}"
    
    # 备份关键配置
    if [[ -d "${WORKSPACE}" ]]; then
        cp -r "${WORKSPACE}"/* "${backup_dir}/" 2>/dev/null || true
    fi
    
    echo "${backup_dir}"
}

# 回滚到备份
rollback() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log "❌ 备份不存在: $backup_dir"
        return 1
    fi
    
    log "🔄 回滚到: $backup_dir"
    
    # 替换当前状态
    if [[ -d "${WORKSPACE}" ]]; then
        rm -rf "${WORKSPACE}.bak" 2>/dev/null || true
        mv "${WORKSPACE}" "${WORKSPACE}.bak"
    fi
    
    cp -r "$backup_dir" "${WORKSPACE}"
    
    log "✅ 回滚完成"
}

# 执行并监控
execute_sandboxed() {
    local script="$1"
    local pre_snapshot post_snapshot backup_dir
    
    log "🚀 开始沙箱执行: $script"
    
    # 安全检查
    if ! analyze_danger "$script"; then
        log "❌ 安全检查失败，拒绝执行"
        return 1
    fi
    
    # 创建备份
    backup_dir=$(backup_state)
    log "📦 备份已创建: $backup_dir"
    
    # 执行前快照
    pre_snapshot=$(save_snapshot "pre-${script##*/}")
    log "📸 执行前快照: $pre_snapshot"
    
    # 执行脚本
    local start_time
    start_time=$(date +%s)
    
    if bash "$script"; then
        local end_time duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # 执行后快照
        post_snapshot=$(save_snapshot "post-${script##*/}")
        log "📸 执行后快照: $post_snapshot"
        
        log "✅ 执行成功 (${duration}s)"
        
        # 验证结果
        if diff -q "${pre_snapshot}/manifest.txt" "${post_snapshot}/manifest.txt" >/dev/null 2>&1; then
            log "⚠️ 警告: 执行前后状态无变化"
        else
            log "✅ 状态已变更"
        fi
        
        return 0
    else
        local exit_code=$?
        log "❌ 执行失败 (退出码: $exit_code)"
        
        # 询问是否回滚
        read -p "是否回滚到执行前状态? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rollback "$backup_dir"
        fi
        
        return $exit_code
    fi
}

# 主命令
case "${1:-}" in
    analyze)
        analyze_danger "$2"
        ;;
    backup)
        backup_state
        ;;
    snapshot)
        save_snapshot "${2:-default}"
        ;;
    rollback)
        rollback "$2"
        ;;
    execute)
        execute_sandboxed "$2"
        ;;
    *)
        echo "用法: $0 {analyze|backup|snapshot|rollback|execute} [参数]"
        echo ""
        echo "命令:"
        echo "  analyze <script>  - 分析脚本安全性"
        echo "  backup            - 创建系统备份"
        echo "  snapshot <label>  - 创建状态快照"
        echo "  rollback <dir>    - 回滚到指定备份"
        echo "  execute <script>  - 沙箱执行脚本"
        ;;
esac