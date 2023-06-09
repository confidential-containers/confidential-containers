FROM alpine:3.14
RUN apk update && apk upgrade && apk add openssh-server
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P ""
# A password needs to be set for login to work. An empty password is
# unproblematic as password-based login to root is not allowed.
RUN passwd -d root
# Generate with `ssh-keygen -t ed25519 -f ccv0-ssh -P "" -C ""`
COPY ccv0-ssh.pub /root/.ssh/authorized_keys
ENTRYPOINT /usr/sbin/sshd -D
