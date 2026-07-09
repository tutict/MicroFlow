# MicroFlow 一键启动脚本
# 支持开发模式和生产模式启动

param(
    [Parameter(Position = 0)]
    [ValidateSet("dev", "prod", "stop", "clean")]
    [string]$Mode = "dev",

    [switch]$SkipBuild,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n==> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

# 检查环境依赖
function Test-Prerequisites {
    Write-Step "检查环境依赖..."

    $missing = @()

    # 检查 Java
    try {
        $javaVersion = java -version 2>&1 | Select-String -Pattern "version" | Select-Object -First 1
        if ($javaVersion -match '"(\d+)') {
            $majorVersion = [int]$Matches[1]
            if ($majorVersion -ge 21) {
                Write-Success "Java $majorVersion 已安装"
            } else {
                $missing += "Java 21+ (当前版本: $majorVersion)"
            }
        }
    } catch {
        $missing += "Java 21+"
    }

    # 检查 Maven
    try {
        $mvnVersion = mvn -version 2>&1 | Select-String -Pattern "Apache Maven" | Select-Object -First 1
        if ($mvnVersion) {
            Write-Success "Maven 已安装"
        }
    } catch {
        $missing += "Maven 3.9+"
    }

    # 检查 Flutter (仅开发模式需要)
    if ($Mode -eq "dev") {
        try {
            $flutterVersion = flutter --version 2>&1 | Select-String -Pattern "Flutter" | Select-Object -First 1
            if ($flutterVersion) {
                Write-Success "Flutter 已安装"
            }
        } catch {
            $missing += "Flutter 3+"
        }
    }

    # 检查 Docker (仅生产模式需要)
    if ($Mode -eq "prod") {
        try {
            $dockerVersion = docker --version 2>&1
            if ($dockerVersion) {
                Write-Success "Docker 已安装"
            }
        } catch {
            $missing += "Docker"
        }

        try {
            $composeVersion = docker compose version 2>&1
            if ($composeVersion) {
                Write-Success "Docker Compose 已安装"
            }
        } catch {
            $missing += "Docker Compose"
        }
    }

    if ($missing.Count -gt 0) {
        Write-Error "缺少以下依赖:"
        $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        exit 1
    }

    Write-Success "所有依赖检查通过"
}

# 检查并创建 .env 文件
function Initialize-Environment {
    Write-Step "初始化环境配置..."

    $envFile = Join-Path $ProjectRoot ".env"
    $envExample = Join-Path $ProjectRoot ".env.example"

    if (-not (Test-Path $envFile)) {
        if (Test-Path $envExample) {
            Copy-Item $envExample $envFile
            Write-Warning "已从 .env.example 创建 .env 文件"
            Write-Warning "请检查并修改 .env 中的敏感配置 (JWT_SECRET, CRYPTO_SECRET)"
        } else {
            Write-Error ".env.example 文件不存在"
            exit 1
        }
    } else {
        Write-Success ".env 文件已存在"
    }

    # 创建数据目录
    $dataDir = Join-Path $ProjectRoot "ops\docker\backend\data"
    $dbDir = Join-Path $ProjectRoot "ops\docker\backend\db"

    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        Write-Success "创建数据目录: $dataDir"
    }

    if (-not (Test-Path $dbDir)) {
        New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        Write-Success "创建数据库目录: $dbDir"
    }
}

# 启动后端 (开发模式)
function Start-BackendDev {
    Write-Step "启动后端 (开发模式)..."

    $backendDir = Join-Path $ProjectRoot "backend"
    Push-Location $backendDir

    try {
        if (-not $SkipBuild) {
            Write-Host "编译后端代码..." -ForegroundColor Yellow
            if ($Verbose) {
                & ./mvnw.cmd clean compile
            } else {
                & ./mvnw.cmd clean compile -q
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Error "后端编译失败"
                exit 1
            }
            Write-Success "后端编译完成"
        }

        Write-Host "启动 Quarkus 开发服务器..." -ForegroundColor Yellow
        Write-Host "访问地址: http://localhost:8080" -ForegroundColor Cyan
        Write-Host "健康检查: http://localhost:8080/api/v1/system/health" -ForegroundColor Cyan
        Write-Host ""

        # 启动 Quarkus dev mode
        & ./mvnw.cmd quarkus:dev

    } finally {
        Pop-Location
    }
}

# 启动前端 (开发模式)
function Start-FrontendDev {
    Write-Step "启动前端 (开发模式)..."

    $frontendDir = Join-Path $ProjectRoot "frontend"
    Push-Location $frontendDir

    try {
        if (-not $SkipBuild) {
            Write-Host "安装 Flutter 依赖..." -ForegroundColor Yellow
            flutter pub get

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Flutter 依赖安装失败"
                exit 1
            }
            Write-Success "Flutter 依赖安装完成"
        }

        Write-Host "启动 Flutter 应用 (Chrome)..." -ForegroundColor Yellow
        Write-Host "访问地址: http://localhost:????  (Flutter 会自动分配端口)" -ForegroundColor Cyan
        Write-Host ""

        # 启动 Flutter 应用
        flutter run -d chrome `
            --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 `
            --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws

    } finally {
        Pop-Location
    }
}

# 启动生产环境 (Docker Compose)
function Start-Production {
    Write-Step "启动生产环境 (Docker Compose)..."

    Push-Location $ProjectRoot

    try {
        if (-not $SkipBuild) {
            Write-Host "构建 Docker 镜像..." -ForegroundColor Yellow
            docker compose build

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Docker 镜像构建失败"
                exit 1
            }
            Write-Success "Docker 镜像构建完成"
        }

        Write-Host "启动 Docker 容器..." -ForegroundColor Yellow
        docker compose up -d

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker 容器启动失败"
            exit 1
        }

        Write-Success "MicroFlow 已启动"
        Write-Host ""
        Write-Host "访问地址:" -ForegroundColor Cyan
        Write-Host "  前端: http://localhost:3000" -ForegroundColor White
        Write-Host "  后端: http://localhost:8080" -ForegroundColor White
        Write-Host "  健康检查: http://localhost:8080/api/v1/system/health" -ForegroundColor White
        Write-Host ""
        Write-Host "查看日志: docker compose logs -f" -ForegroundColor Yellow
        Write-Host "停止服务: .\start.ps1 stop" -ForegroundColor Yellow

    } finally {
        Pop-Location
    }
}

# 停止服务
function Stop-Services {
    Write-Step "停止服务..."

    Push-Location $ProjectRoot

    try {
        docker compose down
        Write-Success "服务已停止"
    } catch {
        Write-Warning "停止服务时出现问题: $_"
    } finally {
        Pop-Location
    }
}

# 清理环境
function Clear-Environment {
    Write-Step "清理环境..."

    Push-Location $ProjectRoot

    try {
        # 停止并删除容器、网络、卷
        docker compose down -v

        # 询问是否删除数据
        $confirmation = Read-Host "是否删除数据库和数据文件? (y/N)"
        if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
            $dataDir = Join-Path $ProjectRoot "ops\docker\backend\data"
            $dbDir = Join-Path $ProjectRoot "ops\docker\backend\db"

            if (Test-Path $dataDir) {
                Remove-Item -Recurse -Force $dataDir
                Write-Success "已删除数据目录"
            }

            if (Test-Path $dbDir) {
                Remove-Item -Recurse -Force $dbDir
                Write-Success "已删除数据库目录"
            }
        }

        Write-Success "环境清理完成"
    } catch {
        Write-Error "清理环境时出现问题: $_"
    } finally {
        Pop-Location
    }
}

# 主流程
function Main {
    Write-ColorOutput @"
╔══════════════════════════════════════════════╗
║          MicroFlow 一键启动脚本              ║
╚══════════════════════════════════════════════╝
"@ "Cyan"

    switch ($Mode) {
        "dev" {
            Test-Prerequisites
            Initialize-Environment

            Write-Host ""
            Write-ColorOutput "开发模式启动选项:" "Yellow"
            Write-Host "  1. 启动后端 (推荐先启动)"
            Write-Host "  2. 启动前端"
            Write-Host "  3. 同时启动后端和前端 (两个终端窗口)"
            Write-Host ""

            $choice = Read-Host "请选择 (1/2/3)"

            switch ($choice) {
                "1" { Start-BackendDev }
                "2" { Start-FrontendDev }
                "3" {
                    Write-Warning "将在两个新窗口中启动后端和前端"
                    Write-Host "按任意键继续..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                    # 启动后端
                    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$ProjectRoot'; .\start.ps1 dev -SkipBuild"

                    # 等待后端启动
                    Write-Host "等待后端启动 (10 秒)..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 10

                    # 启动前端
                    $frontendCmd = "cd '$ProjectRoot\frontend'; flutter run -d chrome --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws"
                    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd

                    Write-Success "后端和前端已在新窗口中启动"
                    Write-Host "按 Ctrl+C 退出各个窗口" -ForegroundColor Yellow
                }
                default {
                    Write-Error "无效选择"
                    exit 1
                }
            }
        }

        "prod" {
            Test-Prerequisites
            Initialize-Environment
            Start-Production
        }

        "stop" {
            Stop-Services
        }

        "clean" {
            Clear-Environment
        }
    }
}

# 执行主流程
try {
    Main
} catch {
    Write-Error "执行过程中出现错误: $_"
    exit 1
}
