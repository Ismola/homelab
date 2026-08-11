#!/usr/bin/env python3
"""Regenera el diagrama de infraestructura del README desde el inventario."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / "ansible/inventory/inventory.yml"
DOCKER_COMPOSE = ROOT / "docker/compose.yml"
APPLICATION_SET = ROOT / "gitops/apps/argocd/files/applicationset.yaml"
README = ROOT / "README.md"
START = "<!-- inventory-diagram:start -->"
END = "<!-- inventory-diagram:end -->"


def mermaid_id(prefix: str, name: str) -> str:
    return prefix + re.sub(r"[^a-zA-Z0-9_]", "_", name)


def provider_label(provider: str) -> str:
    return {"homelab": "Homelab", "oracle": "Oracle Cloud", "google": "Google Cloud"}.get(
        provider, provider.replace("_", " ").title()
    )


def load_hosts() -> tuple[dict, list[dict]]:
    inventory = yaml.safe_load(INVENTORY.read_text(encoding="utf-8"))
    docker_hosts = inventory.get("docker_hosts", {}).get("hosts", {})
    cluster = inventory["k3s_cluster"]["children"]
    k3s_hosts = []
    for role in ("server", "agent"):
        for name, variables in cluster.get(role, {}).get("hosts", {}).items():
            k3s_hosts.append({"name": name, "role": role, **(variables or {})})
    return docker_hosts, k3s_hosts


def load_docker_stacks() -> list[dict]:
    base = yaml.safe_load(DOCKER_COMPOSE.read_text(encoding="utf-8")) or {}
    stacks = []
    for entry in base.get("include", []):
        relative_path = entry["path"] if isinstance(entry, dict) else entry
        compose_path = (DOCKER_COMPOSE.parent / relative_path).resolve()
        if not compose_path.is_relative_to(DOCKER_COMPOSE.parent.resolve()):
            raise ValueError(f"Compose incluido fuera de docker/: {relative_path}")
        compose = yaml.safe_load(compose_path.read_text(encoding="utf-8")) or {}
        stacks.append(
            {
                "name": compose_path.parent.name,
                "services": list(compose.get("services", {}).keys()),
            }
        )
    return stacks


def load_gitops_apps() -> list[str]:
    application_set = yaml.safe_load(APPLICATION_SET.read_text(encoding="utf-8"))
    directories = application_set["spec"]["generators"][0]["git"]["directories"]
    excluded = {
        Path(entry["path"]).name
        for entry in directories
        if entry.get("exclude", False)
    }
    apps = set()
    for entry in directories:
        if entry.get("exclude", False):
            continue
        for path in ROOT.glob(entry["path"]):
            if path.is_dir() and path.name not in excluded:
                apps.add(path.name)
    return sorted(apps)


def render() -> str:
    docker_hosts, k3s_hosts = load_hosts()
    docker_stacks = load_docker_stacks()
    gitops_apps = load_gitops_apps()
    providers = sorted(
        {host.get("provider", "unknown") for host in k3s_hosts},
        key=lambda provider: (provider != "homelab", provider),
    )

    lines = ["```mermaid", "flowchart TB"]
    lines.extend(
        [
            '    client["Clientes"]',
            '    internet["Internet<br/>Cloudflare"]',
            '    tailnet(("Tailscale<br/>tailnet"))',
            '    r2[("Cloudflare R2<br/>Object Storage")]',
            '    workloads["Workloads K3s"]',
            '    longhorn[("Longhorn<br/>Persistent Volumes")]',
            '    databases[("PostgreSQL · MongoDB")]',
            "",
        ]
    )

    for provider in providers:
        provider_hosts = [host for host in k3s_hosts if host.get("provider", "unknown") == provider]
        lines.append(f'    subgraph provider_{mermaid_id("", provider)}["{provider_label(provider)}"]')
        if provider == "homelab":
            for name, variables in docker_hosts.items():
                role = variables.get("role", "host").upper()
                workload = variables.get("workload", "Docker").title()
                lines.append(f'        {mermaid_id("docker_", name)}["{name} · {role}<br/>{workload} workloads"]')
        for host in provider_hosts:
            role = "server / worker" if host["role"] == "server" else "agent / worker"
            lines.append(f'        {mermaid_id("k3s_", host["name"])}["{host["name"]}<br/>K3s {role}"]')
        lines.append("    end")
        lines.append("")

    lines.append('    subgraph docker_deployments["Docker Compose · h0"]')
    for stack in docker_stacks:
        services = " · ".join(stack["services"])
        lines.append(
            f'        {mermaid_id("compose_", stack["name"])}["{stack["name"]}<br/>{services}"]'
        )
    lines.append("    end")
    lines.append("")

    lines.append('    subgraph k3s_deployments["Aplicaciones GitOps · K3s"]')
    for app in gitops_apps:
        lines.append(f'        {mermaid_id("gitops_", app)}["{app}"]')
    lines.append("    end")
    lines.append("")

    lines.extend(
        [
            '    client -->|"servicios públicos"| internet',
            "    internet --> workloads",
            '    client -->|"acceso privado / Split DNS"| tailnet',
        ]
    )
    for name in docker_hosts:
        node_id = mermaid_id("docker_", name)
        lines.append(f"    internet --> {node_id}")
        lines.append(f"    tailnet --- {node_id}")
        if docker_stacks:
            lines.append(f"    {node_id} --> docker_deployments")
    for host in k3s_hosts:
        node_id = mermaid_id("k3s_", host["name"])
        lines.append(f"    tailnet --- {node_id}")
        lines.append(f"    {node_id} -.-> workloads")
    lines.extend(
        [
            "    workloads --> k3s_deployments",
            "    workloads --> databases",
            "    databases --> longhorn",
            '    gitops_longhorn -->|"Backups S3"| compose_minio',
            '    gitops_etcd_backup -->|"Snapshots S3"| compose_minio',
            '    workloads -->|"API S3"| r2',
            "```",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="comprueba sin modificar el README")
    args = parser.parse_args()

    current = README.read_text(encoding="utf-8")
    pattern = re.compile(rf"({re.escape(START)}\n).*?(\n{re.escape(END)})", re.DOTALL)
    if not pattern.search(current):
        raise SystemExit("No se encontraron los marcadores del diagrama en README.md")
    updated = pattern.sub(rf"\1{render()}\2", current, count=1)

    if args.check:
        if updated != current:
            print("README.md no está sincronizado con el inventario")
            return 1
        print("README.md está sincronizado con el inventario")
        return 0

    README.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
