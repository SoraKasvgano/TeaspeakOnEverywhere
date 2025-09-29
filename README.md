# TeaSpeak Multi-Architecture Docker

## 🚀 快速开始

### 一键启动（推荐）
```bash
./quick-start.sh
```

### 构建多架构镜像
```bash
# 使用Python脚本
python3 build_images_fixed.py

# 使用新的多架构脚本
python3 build_multiarch.py -u yourusername

# 使用Makefile
make build-multiarch DOCKER_HUB_USERNAME=yourusername
```

### 手动启动
```bash
# 启动服务
./scripts/start.sh -u yourusername

# 停止服务
./scripts/stop.sh
```

## 🏗️ 多架构支持

- **AMD64**: Intel/AMD 64位处理器
- **ARM64**: ARM 64位处理器 (Apple M1, ARM服务器)
- **ARM32v7**: ARM 32位处理器 (树莓派等)

## 🎯 核心特性

✅ **自适应架构**: `latest`标签自动选择正确架构  
✅ **本地构建**: 使用解压的TeaSpeak-1.4.22目录  
✅ **Manifest合并**: 不同架构自动合并到latest标签  
✅ **完整工具链**: 构建、部署、管理脚本齐全  

## 📋 连接信息

- **语音服务器**: `localhost:9987`
- **ServerQuery**: `localhost:10011`
- **文件传输**: `localhost:30033`

## 📁 项目结构

```
teaspeak_docker-1.4.22/
├── scripts/                      # 管理脚本
├── TeaSpeak-1.4.22/              # TeaSpeak程序文件
├── docker-compose.yml            # Docker Compose配置
├── build_images_fixed.py         # 原版构建脚本
├── build_multiarch.py            # 新版多架构构建脚本
├── quick-start.sh                # 一键启动脚本
├── Makefile                      # 自动化构建
└── .env.example                  # 环境配置模板
```

现在用户可以使用 `yourusername/teaspeak-server:latest` 在任何架构上部署TeaSpeak！