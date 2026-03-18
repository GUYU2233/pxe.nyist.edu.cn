#!/bin/bash
set -e

echo "=== netboot.xyz 编译和打包脚本 ==="
echo "开始时间: $(date)"

# 清理旧的构建输出
echo "清理旧的构建文件..."
rm -rf /tmp/netbootxyz-build
mkdir -p /tmp/netbootxyz-build

# 创建临时输出目录
echo "创建临时输出目录..."
sudo mkdir -p /var/www/html
sudo chown -R $(whoami):$(whoami) /var/www/html

# 运行 Ansible 构建（只生成菜单，不生成磁盘镜像）
echo "开始编译 netboot.xyz..."
ansible-playbook -i inventory site.yml -e "generate_signatures=false generate_disks=false"

# 复制构建产物
echo "复制构建产物..."
BUILD_DIR="/tmp/netbootxyz-build"
mkdir -p ${BUILD_DIR}/www
mkdir -p ${BUILD_DIR}/ssl
cp -r /var/www/html/* ${BUILD_DIR}/www/

# 复制 SSL 证书（用于 nginx 部署）
echo "复制 SSL 证书..."
if [ -f "script/nginx/FullSSL.crt" ] && [ -f "script/nginx/SSL.key" ]; then
    cp script/nginx/FullSSL.crt ${BUILD_DIR}/ssl/pxe.nyist.edu.cn.crt
    cp script/nginx/SSL.key ${BUILD_DIR}/ssl/pxe.nyist.edu.cn.key
    echo "SSL 证书已复制（用于 nginx 部署）"
else
    echo "警告: 未找到 script/nginx/ 目录中的 SSL 证书"
fi

# 创建部署脚本
echo "生成部署脚本..."
cat > ${BUILD_DIR}/deploy.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
set -e

echo "=== netboot.xyz 部署脚本 ==="
echo "部署时间: $(date)"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
  echo "请使用 root 权限运行此脚本"
  exit 1
fi

# 安装 nginx（如果未安装）
if ! command -v nginx &> /dev/null; then
    echo "安装 nginx..."
    if [ -f /etc/redhat-release ]; then
        yum install -y nginx
    elif [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y nginx
    fi
fi

# 部署 SSL 证书
echo "部署 SSL 证书..."
mkdir -p /etc/nginx/ssl
if [ -f "ssl/pxe.nyist.edu.cn.crt" ] && [ -f "ssl/pxe.nyist.edu.cn.key" ]; then
    cp ssl/pxe.nyist.edu.cn.crt /etc/nginx/ssl/
    cp ssl/pxe.nyist.edu.cn.key /etc/nginx/ssl/
    chmod 600 /etc/nginx/ssl/pxe.nyist.edu.cn.key
    echo "SSL 证书已安装"
else
    echo "错误: 未找到 SSL 证书文件"
    exit 1
fi

# 部署文件
echo "部署 PXE 文件..."
mkdir -p /var/www/pxe.nyist.edu.cn
cp -r www/* /var/www/pxe.nyist.edu.cn/
chown -R nginx:nginx /var/www/pxe.nyist.edu.cn

# 配置 nginx
echo "配置 nginx..."
cp nginx.conf /etc/nginx/conf.d/pxe.nyist.edu.cn.conf

# 测试 nginx 配置
nginx -t

# 重启 nginx
echo "重启 nginx..."
systemctl enable nginx
systemctl restart nginx

echo "部署完成！"
echo "访问地址: https://pxe.nyist.edu.cn"
DEPLOY_SCRIPT

chmod +x ${BUILD_DIR}/deploy.sh

# 创建 nginx 配置文件
echo "生成 nginx 配置..."
cat > ${BUILD_DIR}/nginx.conf << 'NGINX_CONF'
server {
    listen 80;
    listen [::]:80;
    server_name pxe.nyist.edu.cn;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name pxe.nyist.edu.cn;

    ssl_certificate /etc/nginx/ssl/pxe.nyist.edu.cn.crt;
    ssl_certificate_key /etc/nginx/ssl/pxe.nyist.edu.cn.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /var/www/pxe.nyist.edu.cn;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }

    location ~ \.ipxe$ {
        default_type text/plain;
    }

    access_log /var/log/nginx/pxe.nyist.edu.cn.access.log;
    error_log /var/log/nginx/pxe.nyist.edu.cn.error.log;
}
NGINX_CONF

# 创建 README 文件
echo "生成 README..."
cat > ${BUILD_DIR}/README.md << 'README'
# netboot.xyz 部署包

## 部署说明

### 1. 上传文件
将整个 tar.gz 包上传到目标服务器并解压：
```bash
tar -xzf netbootxyz-deploy-*.tar.gz
cd netbootxyz-deploy
```

### 2. 运行部署脚本
SSL 证书已包含在部署包中，直接运行部署脚本即可：
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

### 4. 验证部署
访问 https://pxe.nyist.edu.cn 确认服务正常运行。

## 文件说明
- `www/` - PXE 启动文件和菜单
- `nginx.conf` - Nginx 配置文件
- `deploy.sh` - 自动部署脚本
- `README.md` - 本说明文件

## 技术支持
南阳理工学院 CIPS 协会
README

# 打包
echo "打包部署文件..."
cd /tmp
PACKAGE_NAME="netbootxyz-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf ${PACKAGE_NAME} -C netbootxyz-build .

echo "=== 编译和打包完成 ==="
echo "部署包位置: /tmp/${PACKAGE_NAME}"
echo "部署包大小: $(du -h /tmp/${PACKAGE_NAME} | cut -f1)"
echo "完成时间: $(date)"
