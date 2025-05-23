#!/bin/bash

# === 获取用户输入 ===
read -p "请输入你的域名（如 example.com）: " DOMAIN
read -p "请输入你的邮箱（用于 SSL 证书）: " EMAIL
read -p "数据库名: " DB_NAME
read -p "数据库用户名: " DB_USER
read -s -p "数据库密码: " DB_PASS
echo ""

# === 安装组件 ===
apt update && apt install -y nginx mysql-server php8.1 php8.1-fpm php8.1-mysql \
php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.1-gd php8.1-bcmath php8.1-cli \
git unzip curl nodejs npm composer certbot python3-certbot-nginx

# === 创建数据库 ===
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS \`${DB_USER}\`@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO \`${DB_USER}\`@'localhost';
FLUSH PRIVILEGES;
EOF

# === 克隆代码 ===
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

# === 临时 HTTP 配置 (无证书) ===
cat <<EOF > /etc/nginx/sites-available/beikeshop
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
EOF

ln -sf /etc/nginx/sites-available/beikeshop /etc/nginx/sites-enabled/beikeshop
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# === 签发 HTTPS 证书 ===
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}

# === 写入正式 HTTPS 配置 ===
cat <<EOF > /etc/nginx/sites-available/beikeshop
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
EOF

nginx -t && systemctl reload nginx

# === 防火墙 ===
ufw allow 'Nginx Full' || true

# === 完成 ===
echo "✅ BeikeShop 安装完成！访问：https://${DOMAIN}"
