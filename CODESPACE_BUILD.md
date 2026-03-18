# Codespace 编译指南

## 在 GitHub Codespace 中编译

### 1. 创建 Codespace
在 GitHub 仓库页面点击 "Code" -> "Codespaces" -> "Create codespace on main"

### 2. 运行编译脚本
```bash
cd /workspaces/pxe.nyist.edu.cn
chmod +x script/build_and_package.sh
./script/build_and_package.sh
```

### 3. 下载部署包
编译完成后，部署包位于 `/tmp/netbootxyz-deploy-YYYYMMDD-HHMMSS.tar.gz`

在 Codespace 终端中运行：
```bash
# 查看生成的文件
ls -lh /tmp/netbootxyz-deploy-*.tar.gz

# 下载到本地（使用 Codespace 的下载功能）
# 或者使用 GitHub CLI
gh codespace cp remote:/tmp/netbootxyz-deploy-*.tar.gz ./
```

## 部署到生产服务器

### 1. 上传部署包
```bash
scp netbootxyz-deploy-*.tar.gz root@pxe.nyist.edu.cn:/tmp/
```

### 2. 解压并部署
SSL 证书已包含在部署包中，直接部署即可：
```bash
ssh root@pxe.nyist.edu.cn
cd /tmp
tar -xzf netbootxyz-deploy-*.tar.gz
cd netbootxyz-deploy

# 运行部署（SSL 证书会自动安装）
chmod +x deploy.sh
./deploy.sh
```

### 3. 验证
访问 https://pxe.nyist.edu.cn

## 注意事项

- 编译过程需要约 10-30 分钟，取决于网络速度
- 确保 Codespace 有足够的磁盘空间（建议 4GB+）
- 部署包大小约 500MB-2GB
- 生产服务器需要已配置好 SSL 证书
