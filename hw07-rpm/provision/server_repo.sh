#/bin/sh

# nginx install
echo "nginx installation"
dnf install -qy nginx createrepo
systemctl start nginx
systemctl enable nginx

echo "rpm build"
cd ~
dnf install -qy rpmdevtools rpmlint gcc libxml2-devel sqlite-devel
wget -q https://www.php.net/distributions/php-8.0.22.tar.gz
tar -xf php-8.0.22.tar.gz
rpmdev-setuptree
cp php-8.0.22.tar.gz ./rpmbuild/SOURCES/
cp /vagrant/php.spec ~/rpmbuild/SPECS/php.spec
rpmbuild --quiet -bb ~/rpmbuild/SPECS/php.spec

echo "create repo"
mkdir -p /usr/share/nginx/html/repo/x86_64
cp ~/rpmbuild/RPMS/x86_64/php-8.0.22-1.el8.x86_64.rpm /usr/share/nginx/html/repo/x86_64
createrepo /usr/share/nginx/html/repo/x86_64
