Name:           php
Version:        8.0.22
Release:        1%{?dist}
Summary:        Php build by gam6itko

License:        GPL
URL:            https://www.php.net/
Source0:        https://www.php.net/distributions/php-8.0.22.tar.gz

BuildRequires:  libxml2-devel
BuildRequires:  sqlite-devel

%description


%prep
%autosetup

%build
./configure --enable-zts
make -j$(nproc)

%install
make install

%{__mkdir} -p %{buildroot}/usr/local/bin
%{__mv} /usr/local/bin/phar.phar %{buildroot}/usr/local/bin/phar.phar
%{__mv} /usr/local/bin/php %{buildroot}/usr/local/bin/php
%{__mv} /usr/local/bin/php-cgi %{buildroot}/usr/local/bin/php-cgi
%{__mv} /usr/local/bin/php-config %{buildroot}/usr/local/bin/php-config
%{__mv} /usr/local/bin/phpdbg %{buildroot}/usr/local/bin/phpdbg
%{__mv} /usr/local/bin/phpize %{buildroot}/usr/local/bin/phpize

%{__mkdir} -p %{buildroot}/usr/local/include/
%{__mv} /usr/local/include/php %{buildroot}/usr/local/include/

%{__mkdir} %{buildroot}/usr/local/lib/
%{__mv} /usr/local/lib/php %{buildroot}/usr/local/lib/

%{__mkdir} %{buildroot}/usr/local/php/
%{__mv} /usr/local/php %{buildroot}/usr/local/php/

%{__mkdir} -p %{buildroot}/usr/local/var/{log,run}

%files

/usr/local/bin
/usr/local/include
/usr/local/lib
/usr/local/php
/usr/local/var

%changelog
* Sun Aug 28 2022 root
- 
