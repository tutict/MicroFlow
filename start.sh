#!/usr/bin/env bash
# MicroFlow 一键启动脚本 (Linux/macOS)
# 支持开发模式和生产模式启动

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-dev}"
SKIP_BUILD=false
VERBOSE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        dev|prod|stop|clean)
            MODE="$1"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${CYAN}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 检查环境依赖
check_prerequisites() {
    print_step "检查环境依赖..."

    local missing=()

    # 检查 Java
    if command -v java &> /dev/null; then
        local java_version=$(java -version 2>&1 | grep -oP 'version "?\K[0-9]+' | head -1)
        if [[ $java_version -ge 21 ]]; then
            print_success "Java $java_version 已安装"
        else
            missing+=("Java 21+ (当前版本: $java_version)")
        fi
    else
        missing+=("Java 21+")
    fi

    # 检查 Maven
    if command -v mvn &> /dev/null; then
        print_success "Maven 已安装"
    else
        missing+=("Maven 3.9+")
    fi

    # 检查 Flutter (仅开发模式需要)
    if [[ "$MODE" == "dev" ]]; then
        if command -v flutter &> /dev/null; then
            print_success "Flutter 已安装"
        else
            missing+=("Flutter 3+")
        fi
    fi

    # 检查 Docker (仅生产模式需要)
    if [[ "$MODE" == "prod" ]]; then
        if command -v docker &> /dev/null; then
            print_success "Docker 已安装"
        else
            missing+=("Docker")
        fi

        if docker compose version &> /dev/null; then
            print_success "Docker Compose 已安装"
        else
            missing+=("Docker Compose")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "缺少以下依赖:"
        for dep in "${missing[@]}"; do
            echo -e "  ${RED}- $dep${NC}"
        done
        exit 1
    fi

    print_success "所有依赖检查通过"
}

# 初始化环境
initialize_environment() {
    print_step "初始化环境配置..."

    local env_file="$PROJECT_ROOT/.env"
    local env_example="$PROJECT_ROOT/.env.example"

    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_file"
            print_warning "已从 .env.example 创建 .env 文件"
            print_warning "请检查并修改 .env 中的敏感配置 (JWT_SECRET, CRYPTO_SECRET)"
        else
            print_error ".env.example 文件不存在"
            exit 1
        fi
    else
        print_success ".env 文件已存在"
    fi

    # 创建数据目录
    local data_dir="$PROJECT_ROOT/ops/docker/backend/data"
    local db_dir="$PROJECT_ROOT/ops/docker/backend/db"

    mkdir -p "$data_dir"
    mkdir -p "$db_dir"
    print_success "数据目录已就绪"
}

# 启动后端 (开发模式)
start_backend_dev() {
    print_step "启动后端 (开发模式)..."

    cd "$PROJECT_ROOT/backend"

    if [[ "$SKIP_BUILD" != true ]]; then
        echo "编译后端代码..."
        if [[ "$VERBOSE" == true ]]; then
            ./mvnw clean compile
        else
            ./mvnw clean compile -q
        fi

        if [[ $? -ne 0 ]]; then
            print_error "后端编译失败"
            exit 1
        fi
        print_success "后端编译完成"
    fi

    echo -e "${YELLOW}启动 Quarkus 开发服务器...${NC}"
    echo -e "${CYAN}访问地址: http://localhost:8080${NC}"
    echo -e "${CYAN}健康检查: http://localhost:8080/api/v1/system/health${NC}"
    echo ""

    ./mvnw quarkus:dev
}

# 启动前端 (开发模式)
start_frontend_dev() {
    print_step "启动前端 (开发模式)..."

    cd "$PROJECT_ROOT/frontend"

    if [[ "$SKIP_BUILD" != true ]]; then
        echo "安装 Flutter 依赖..."
        flutter pub get

        if [[ $? -ne 0 ]]; then
            print_error "Flutter 依赖安装失败"
            exit 1
        fi
        print_success "Flutter 依赖安装完成"
    fi

    echo -e "${YELLOW}启动 Flutter 应用 (Chrome)...${NC}"
    echo -e "${CYAN}访问地址: http://localhost:???? (Flutter 会自动分配端口)${NC}"
    echo ""

    flutter run -d chrome \
        --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 \
        --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws
}

# 启动生产环境 (Docker Compose)
start_production() {
    print_step "启动生产环境 (Docker Compose)..."

    cd "$PROJECT_ROOT"

    if [[ "$SKIP_BUILD" != true ]]; then
        echo "构建 Docker 镜像..."
        docker compose build

        if [[ $? -ne 0 ]]; then
            print_error "Docker 镜像构建失败"
            exit 1
        fi
        print_success "Docker 镜像构建完成"
    fi

    echo "启动 Docker 容器..."
    docker compose up -d

    if [[ $? -ne 0 ]]; then
        print_error "Docker 容器启动失败"
        exit 1
    fi

    print_success "MicroFlow 已启动"
    echo ""
    echo -e "${CYAN}访问地址:${NC}"
    echo "  前端: http://localhost:3000"
    echo "  后端: http://localhost:8080"
    echo "  健康检查: http://localhost:8080/api/v1/system/health"
    echo ""
    echo -e "${YELLOW}查看日志: docker compose logs -f${NC}"
    echo -e "${YELLOW}停止服务: ./start.sh stop${NC}"
}

# 停止服务
stop_services() {
    print_step "停止服务..."

    cd "$PROJECT_ROOT"
    docker compose down
    print_success "服务已停止"
}

# 清理环境
clean_environment() {
    print_step "清理环境..."

    cd "$PROJECT_ROOT"

    # 停止并删除容器、网络、卷
    docker compose down -v

    # 询问是否删除数据
    read -p "是否删除数据库和数据文件? (y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_ROOT/ops/docker/backend/data"
        rm -rf "$PROJECT_ROOT/ops/docker/backend/db"
        print_success "已删除数据目录"
    fi

    print_success "环境清理完成"
}

# 显示使用说明
show_usage() {
    cat << EOF
Usage: ./start.sh [MODE] [OPTIONS]

MODE:
  dev       启动开发模式 (默认)
  prod      启动生产模式 (Docker Compose)
  stop      停止服务
  clean     清理环境

OPTIONS:
  --skip-build    跳过构建步骤
  --verbose       显示详细输出

Examples:
  ./start.sh dev              # 启动开发模式
  ./start.sh prod             # 启动生产模式
  ./start.sh stop             # 停止服务
  ./start.sh clean            # 清理环境
EOF
}

# 主流程
main() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════╗
║          MicroFlow 一键启动脚本              ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    case "$MODE" in
        dev)
            check_prerequisites
            initialize_environment

            echo ""
            echo -e "${YELLOW}开发模式启动选项:${NC}"
            echo "  1. 启动后端 (推荐先启动)"
            echo "  2. 启动前端"
            echo "  3. 同时启动后端和前端 (两个终端窗口)"
            echo ""

            read -p "请选择 (1/2/3): " choice

            case "$choice" in
                1)
                    start_backend_dev
                    ;;
                2)
                    start_frontend_dev
                    ;;
                3)
                    print_warning "将在两个新终端窗口中启动后端和前端"

                    # 检测终端类型并启动后端
                    if command -v gnome-terminal &> /dev/null; then
                        gnome-terminal -- bash -c "cd '$PROJECT_ROOT/backend' && ./mvnw quarkus:dev; exec bash"
                        sleep 10
                        gnome-terminal -- bash -c "cd '$PROJECT_ROOT/frontend' && flutter run -d chrome --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws; exec bash"
                    elif command -v xterm &> /dev/null; then
                        xterm -e "cd '$PROJECT_ROOT/backend' && ./mvnw quarkus:dev; exec bash" &
                        sleep 10
                        xterm -e "cd '$PROJECT_ROOT/frontend' && flutter run -d chrome --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws; exec bash" &
                    elif [[ "$OSTYPE" == "darwin"* ]]; then
                        osascript -e "tell app \"Terminal\" to do script \"cd '$PROJECT_ROOT/backend' && ./mvnw quarkus:dev\""
                        sleep 10
                        osascript -e "tell app \"Terminal\" to do script \"cd '$PROJECT_ROOT/frontend' && flutter run -d chrome --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws\""
                    else
                        print_error "无法检测终端类型,请手动在两个终端中运行:"
                        echo -e "  ${CYAN}终端1:${NC} cd backend && ./mvnw quarkus:dev"
                        echo -e "  ${CYAN}终端2:${NC} cd frontend && flutter run -d chrome --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws"
                        exit 1
                    fi

                    print_success "后端和前端已在新终端中启动"
                    ;;
                *)
                    print_error "无效选择"
                    exit 1
                    ;;
            esac
            ;;

        prod)
            check_prerequisites
            initialize_environment
            start_production
            ;;

        stop)
            stop_services
            ;;

        clean)
            clean_environment
            ;;

        help|--help|-h)
            show_usage
            ;;

        *)
            print_error "无效模式: $MODE"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主流程
main
