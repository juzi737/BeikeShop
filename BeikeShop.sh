#!/bin/bash

echo "请输入你绑定的域名（如 example.com）："
read DOMAIN

if [ -z "$DOMAIN" ]; then
  echo "❌ 域名不能为空，脚本终止"
  exit 1
fi

echo "请输入你的邮箱（用于申请 SSL 证书）："
read EMAIL

if [ -z "$EMAIL" ]; then
  echo "❌ 邮箱不能为空，脚本终止"
  exit 1
fi

echo "请输入你要创建的 MySQL 数据库名（如 beikeshop）："
read DB_NAME

echo "请输入数据库用户名（如 shopuser）："
read DB_USER

echo "请输入数据库密码（强密码推荐）："
read -s DB_PASS
echo ""

echo "[1/8] 安装组件..."
apt update && apt install -y nginx mysql-server php8.1 php8.1-fpm php8.1-mysql \
php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.1-gd php8.1-bcmath php8.1-cli \
git unzip curl nodejs npm composer certbot python3-certbot-nginx dos2unix

echo "[2/8] 配置数据库..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS \`${DB_USER}\`@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO \`${DB_USER}\`@'localhost';
FLUSH PRIVILEGES;
EOF

echo "[3/8] 下载 BeikeShop..."
rm -rf /var/www/beikeshop
git clone https://github.com/beikeshop/beikeshop.git /var/www/beikeshop
cd /var/www/beikeshop
composer install
cp .env.example .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env
php artisan key:generate
php artisan migrate
npm install && npm run prod
chown -R www-data:www-data /var/www/beikeshop
chmod -R 755 /var/www/beikeshop

echo "[4/8] 写入临时 Nginx 配置..."
cat <<NGINX > /etc/nginx/sites-available/beikeshop
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/beikeshop/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/beikeshop /etc/nginx/sites-enabled/beikeshop
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "[5/8] 签发 HTTPS 证书..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}

echo "[6/8] 写入正式 HTTPS 配置..."
cat <<SSL > /etc/nginx/sites-available/beikeshop
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    root /var/www/beikeshop/public;
    index index.php index.html;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
SSL

nginx -t && systemctl reload nginx

echo "[7/8] 配置防火墙（如启用 UFW）..."
ufw allow 'Nginx Full' || true

echo "[8/8] ✅ BeikeShop 安装完成！请访问：https://${DOMAIN}"
echo "数据库配置："
echo "  数据库名：${DB_NAME}"
echo "  用户名：${DB_USER}"
echo "  密码：${DB_PASS}"
