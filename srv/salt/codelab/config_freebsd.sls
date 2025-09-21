/compat/linux/etc/pki/tls/certs:
  file.directory

Fix .NET access problem SSL CA cert path:
  file.symlink:
    - name: /compat/linux/etc/pki/tls/certs/ca-bundle.crt
    - target: /usr/local/share/certs/ca-root-nss.crt
