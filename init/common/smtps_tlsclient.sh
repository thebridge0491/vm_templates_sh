#!/bin/sh

# usage: env USE_CURL=0 sh smtps_tlsclient.sh hdr msg [host]

                                 # [mail.yahoo.com | gmail.com | comcast.net]
USE_CURL=${USE_CURL:-0}
hdr=${1:-hdr.txt} ; msg=${2:-msg.txt} ; host=${3:-smtp.mail.yahoo.com}

sender=$(sed -n 's|From: \(.*\)|\1|ip' ${hdr})
recip=$(sed -n 's|To: \(.*\)|\1|ip' ${hdr})
port=465

stty -echo
read -p "Host password for user($sender): " passw ; echo
stty echo

if [ "0" = "${USE_CURL}" ] ; then
  result=$(printf "\0${sender}\0${passw}" | openssl base64)
  
  {
  echo "ehlo ${host}" ; sleep 2 ;
  echo "helo ${host}" ; sleep 2 ;
  echo "auth plain ${result}" ; sleep 2 ;
  echo "mail from: <${sender}>" ; sleep 2 ;
  echo "rcpt to: <${recip}>" ; sleep 2 ;
  echo "data" ; sleep 2 ;
  cat ${hdr} ${msg} ; sleep 2 ;
  echo "." ; sleep 2 ;
  } | openssl s_client -crlf -connect ${host}":"${port}
  #} | gnutls-cli --crlf --insecure --no-ca-verification --port ${port} ${host}
  
  # (openssl s_client) ??? Linux: -CApath ...      ; macOS: -CAfile ...
  # (gnutls-cli)       ??? Linux: --x509cafile ... ; macOS: --x509cafile ...
else
  cat ${hdr} ${msg} | curl -k --crlf --ssl --user ${sender}":"${passw} \
    --mail-from ${sender} --upload-file - --mail-rcpt ${recip} \
    --url smtps://${host}":"${port} ;
fi
