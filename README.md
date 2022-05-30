![logo](./images/coco_logo.png)

# Welcome to documentation repository for Confidential Containers 

Confidential Containers is an open source community working to leverage 
[Trusted Execution Environments](https://en.wikipedia.org/wiki/Trusted_execution_environment) 
to protect containers and data and to deliver cloud native 
confidential computing.

Our key considerations are:
- Allow cloud native application owners to enforce application security requirements
- Transparent deployment of unmodified containers
- Support for multiple TEE and hardware platforms
- A trust model which separates Cloud Service Providers (CSPs) from guest applications
- Least privilege principles for the Kubernetes cluster administration capabilities which impact 
delivering Confidential Computing for guest applications or data inside the TEE

## Further Detail

[![asciicast](https://asciinema.org/a/eGHhZdQY3uYnDalFAfuB7VYqF.svg)](https://asciinema.org/a/eGHhZdQY3uYnDalFAfuB7VYqF)

- [Project Overview](./Overview.md)
- [Our Roadmap](./Roadmap.md)
- [Alignment with other Projects](ALIGNMENT.md)


### Associated Repositories
- [Kubernetes Operator for Confidential Computing](https://github.com/confidential-containers/confidential-containers-operator)
: An operator to deploy confidential containers runtime (and required configs) on a Kubernetes cluster
