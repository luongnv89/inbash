# inbash

<p align="center">
  <img src="./assets/inbash-logo.svg" alt="inbash logo" width="220" />
</p>

Curated Bash scripts for quickly bootstrapping development environments on Linux and macOS. Each script now includes usage examples, safety prompts, logging, and updated installation steps.

## UNIX scripts (`unix/`)

| Script | Summary |
| --- | --- |
| [`basic.sh`](./unix/basic.sh) | Installs baseline CLI tooling (`git`, `vim`, `wget`) with optional non-interactive mode. |
| [`c_cpp.sh`](./unix/c_cpp.sh) | Sets up a C/C++ toolchain (`build-essential`, `cmake`, `gdb`, etc.) and cleans apt caches. |
| [`docker.sh`](./unix/docker.sh) | Adds Docker’s official repo, installs Engine/CLI/Compose plugins, and can optionally remove the repo entry afterwards. |
| [`install-mongodb.sh`](./unix/install-mongodb.sh) | Configures MongoDB’s apt repo (default v8.0), installs `mongodb-org`, and ensures `mongod` is enabled. |
| [`mount-share.sh`](./unix/mount-share.sh) | Mounts a VirtualBox shared folder with module verification and helpful troubleshooting tips. |
| [`nodejs.sh`](./unix/nodejs.sh) | Installs the latest Node.js LTS release via NodeSource with optional repo cleanup. |
| [`python3-pip.sh`](./unix/python3-pip.sh) | Installs `python3-pip` and updates `python`/`pip` alternatives to point at Python 3. |
| [`scapy.sh`](./unix/scapy.sh) | Prepares system dependencies and installs Scapy (Python 3) plus optional HTTP helpers. |
| [`show_ip`](./unix/show_ip) | Generates the SSH login banner showing active IPv4 addresses; supports dry-run and custom targets. |
| [`show_ip_login.sh`](./unix/show_ip_login.sh) | Installs the `show_ip` hook into `/etc/network/if-{up,post-down}.d` with backups and prompts. |
| [`update_network_interfaces.sh`](./unix/update_network_interfaces.sh) | Deploys a templated `/etc/network/interfaces` file with backups and selectively brings interfaces online. |
| [`valgrind.sh`](./unix/valgrind.sh) | Installs Valgrind and prints the installed version after cleanup. |

> **Note:** Legacy scripts (`tomahawk.sh`, `gxx4.9.sh`, etc.) were removed from this listing because they are not currently maintained. Reintroduce them only after auditing and modernizing.

## macOS scripts (`mac/`)

| Script | Summary |
| --- | --- |
| [`app-removal-analyzer.sh`](./mac/app-removal-analyzer.sh) | Interactive, dry-run assistant for auditing and creating removal plans for macOS applications across package managers. |

## Root-level scripts

| Script | Summary |
| --- | --- |
| [`install-zsh.sh`](./install-zsh.sh) | Installs Zsh, fetches Oh My Zsh, and optionally sets Zsh as the default shell. |
| [`setup-ohMyZsh.sh`](./setup-ohMyZsh.sh) | Installs recommended Oh My Zsh plugins and deploys the bundled `zshrc-config`. |

### Usage tips

1. Review scripts before execution—each now offers a `--help` flag with detailed usage.
2. Prefer running with `--dry-run` or without `--yes` first to ensure you understand the operations.
3. Run scripts with elevated privileges where required (`sudo ./script.sh`).