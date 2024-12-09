#!/bin/bash

projdir=$(dirname $0)
if test $# -ne 2; then
   echo "Usage: $0 <admin_secret_b64> <username>"
   echo "with"
   echo "   <admin_secret_b64> = copy value from the latest successful APPLY job"
   echo "                        of the corresponding OCI Stack"
   echo "   <username>         = name of the admin user"
   echo
   exit 1
fi

if command -v openssl 2>&1 > /dev/null; then :; else
   echo "ERROR: openssl not found."
   exit 1
fi
if command -v xxd 2>&1 > /dev/null; then :; else
   echo "ERROR: xxd not found."
   exit 1
fi

if test x"$1" = x""; then
   echo "ERROR: Parameter <secret> not specified."
   exit 1
fi
secret_b64=$1

if test x"$2" = x""; then
   echo "ERROR: Parameter <username> not specified."
   exit 1
fi
username=$2

jwt_header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)
payload=$(echo -n "{\"username\":\"$username\"}" | base64 | sed s/\+/-/g |sed 's/\//_/g' |  sed -E s/=+$//)
hexsecret=$(echo -n "$secret_b64" | base64 -d | xxd -p | paste -sd "")

#echo -n "$secret" | base64

hmac_signature=$(echo -n "${jwt_header}.${payload}" |  openssl dgst -sha256 -mac HMAC -macopt hexkey:$hexsecret -binary | base64  | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)

jwt="${jwt_header}.${payload}.${hmac_signature}"

echo $jwt