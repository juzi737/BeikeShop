# BeikeShop 一键部署脚本

这是一个适用于任意 Ubuntu VPS 的自动化部署脚本，可一键安装 [BeikeShop](https://github.com/beikeshop/beikeshop) 系统，包含：

- PHP 8.1
- MySQL 数据库
- Nginx + HTTPS 证书自动签发
- Laravel 配置初始化
- Node 构建前端资源
- 权限与依赖自动处理

---

## ✅ 环境要求

- 系统：Ubuntu 20.04 / 22.04 / 24.04
- 内存：1GB 以上
- 开放端口：80 / 443（用于 HTTP 和 HTTPS）

---

## 🚀 快速使用命令（推荐）

在任意新服务器上执行以下命令：

```bash
curl -O https://raw.githubusercontent.com/juzi737/BeikeShop/main/BeikeShop.sh
chmod +x BeikeShop.sh
./BeikeShop.sh
