#/bin/sh

dnf install -qy wget tree mc
# configure
dnf install -qy gcc libxml2-devel sqlite-devel
# make
dnf install -qy make
# rpm
dnf install -qy rpmdevtools rpmlint

