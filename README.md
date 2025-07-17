# SOFA

Welcome to the sofa-local repository. This project provides a Docker based deployment solution for OpenSearch clusters, designed to support cybersecurity research and educational activities within our organization.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## What is SOFA?
SOFA (Suricata, OpenSearch, FluentBit, Anubis) is comprehensive network security and web protection platform that combines Suricata IDS/IPS for network threat detection, OpenSearch for data storage and search, FluentBit for log processing and forwarding, and Anubis for web application protection against AI crawlers and automated abuse. This integrated stack provides multi-layered security monitoring, centralized logging, and protection against both network-level threats and application-layer abuse.

## Project Status

This repository is currently in the **development phase**. The current implementation provides basic OpenSearch cluster deployment functionality, but there are ambitious plans for expansion to complete the SOFA stack implementation as a repository that is production deployment ready!

### What's Working Now
- Three-node OpenSearch cluster deployment
- Dynamic configuration generation (opensearch.yml, tenants.yml, internal_users.yml)
- Automated hash generation based on environment variables
- Local development environment setup

## Prerequisites
- Docker Engine 20.10+ and Docker Compose 2.0+
- Minimum 8GB RAM (16GB recommended)
- 30GB of available disk space
- Linux, macOS, or Windows with WSL2

## Quickstart

To just run and explore the OpenSearch part of SOFA:
```zsh
cp .env.exmaple .env
bash start-sofa-local.sh
```

You'll be able to access OpenSearch Dashboards here:
```zsh
https://localhost:5601
```

## Environment Setup
You must edit the .env file with your configuration. Otherwise it'll use defaults.

### Priority Areas
- Infrastructure: Improve Docker configurations and deployment scripts
- Security: Enhance security configurations and best practices
- Documentation: Create guides, tutorials, and API documentation
- Testing: Develop automated tests and validation scripts
- Integration: Connect with other cybersecurity tools and platforms

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.


