#!/bin/sh

usage="usage: 
	${0} mime_attachmt [data]
	${0} mime_mixed [data [body]]"

mime_attachmt() {
	data=${1:-data.txt}
	
	cat << EOF
Content-Type: $(file --brief --mime-type $data); name="$(basename $data)"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$(basename $data)"

$(openssl base64 -in $data)
EOF
}

mime_mixed() {
	data=${1:-data.txt} ; body=${2:-/dev/stdin}

	md5_cmd='md5sum'
	if [ "$(uname -s)" != 'Linux' ] ; then
		md5_cmd="md5" ;
	fi
	boundary=$(date +%s | ${md5_cmd} | awk '{print $1;}')

	cat << EOF
Content-Type: multipart/mixed; boundary="${boundary}"

This is a multi-part message in MIME format.

--${boundary}
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: 7bit
Content-Disposition: inline

$(echo "Enter body(file: $data): " > /dev/stderr)
$(cat $body)

--${boundary}
$(mime_attachmt $data)

--${boundary}--
EOF
}

is_function="0"
case "$1" in
	"mime_attachmt") is_function="1" ;;
	"mime_mixed") is_function="1" ;;
esac
if [ "0" = "${is_function}" ] ; then
	printf "${usage}\n" ; exit ;
fi
func=$1 ; shift
${func} $@
