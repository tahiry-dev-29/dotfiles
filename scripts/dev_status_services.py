#!/usr/bin/env python3
"""
Services discovery and lifecycle management adapter for dev-status TUI.
Discovers systemd, Docker, and local service processes.
Normalizes all services into a common model with safe stop AND start capabilities.
"""
import subprocess
import shutil
import re
from typing import List, Dict, Any, Optional

SYSTEMD_SERVICES = [
    {"name": "PostgreSQL", "unit": "postgresql", "port": 5432},
    {"name": "Redis", "unit": "redis-server", "port": 6379},
    {"name": "MySQL", "unit": "mysql", "port": 3306},
    {"name": "MongoDB", "unit": "mongod", "port": 27017},
    {"name": "Docker", "unit": "docker", "port": 0},
    {"name": "Nginx", "unit": "nginx", "port": 80},
]

def discover_services() -> List[Dict[str, Any]]:
    """
    Returns normalized list of services:
    [{
        'name': 'PostgreSQL',
        'state': 'running' | 'stopped',
        'pid': 2124 | None,
        'port': 5432,
        'provider': 'systemd' | 'docker',
        'uptime': '2h 14m',
        'unit': 'postgresql',
        'container_id': None,
        'details': '...'
    }]
    """
    services: List[Dict[str, Any]] = []

    # 1. Systemd / Systemctl Discovery
    if shutil.which("systemctl"):
        for s in SYSTEMD_SERVICES:
            unit = s["unit"]
            try:
                res = subprocess.run(["systemctl", "is-active", unit], capture_output=True, text=True)
                is_active = (res.stdout.strip() == "active")
                state = "running" if is_active else "stopped"
                
                pid = None
                uptime = "N/A"
                if is_active:
                    prop_res = subprocess.run(
                        ["systemctl", "show", unit, "--property=MainPID,ActiveEnterTimestampMonotonic,ActiveEnterTimestamp"],
                        capture_output=True, text=True
                    )
                    for line in prop_res.stdout.splitlines():
                        if line.startswith("MainPID="):
                            raw_pid = line.split("=", 1)[1].strip()
                            if raw_pid.isdigit() and int(raw_pid) > 0:
                                pid = int(raw_pid)
                        elif line.startswith("ActiveEnterTimestamp="):
                            ts = line.split("=", 1)[1].strip()
                            if ts:
                                uptime = ts

                services.append({
                    "name": s["name"],
                    "state": state,
                    "pid": pid,
                    "port": s["port"],
                    "provider": "systemd",
                    "uptime": uptime,
                    "unit": unit,
                    "container_id": None,
                    "id": f"systemd:{unit}"
                })
            except Exception:
                pass

    # 2. Docker Containers Discovery
    if shutil.which("docker"):
        try:
            res = subprocess.run(
                ["docker", "ps", "-a", "--format", "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"],
                capture_output=True, text=True
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    parts = line.split("\t")
                    if len(parts) >= 3:
                        cid = parts[0].strip()
                        cname = parts[1].strip()
                        status_str = parts[2].strip()
                        ports_str = parts[3].strip() if len(parts) >= 4 else ""

                        is_up = status_str.lower().startswith("up")
                        state = "running" if is_up else "stopped"
                        
                        port_match = re.search(r':(\d+)->', ports_str)
                        port = int(port_match.group(1)) if port_match else 0

                        services.append({
                            "name": cname,
                            "state": state,
                            "pid": None,
                            "port": port,
                            "provider": "docker",
                            "uptime": status_str,
                            "unit": None,
                            "container_id": cid,
                            "id": f"docker:{cid}"
                        })
        except Exception:
            pass

    return services

def stop_service_safely(svc: Dict[str, Any], sudo_password: Optional[str] = None) -> tuple[bool, str]:
    """Safely stop a service without shell eval."""
    provider = svc.get("provider")
    name = svc.get("name", "Unknown")

    if provider == "systemd":
        unit = svc.get("unit")
        if not unit:
            return False, f"Missing unit for {name}"
        cmd = ["sudo", "-S", "systemctl", "stop", unit] if sudo_password else ["sudo", "-n", "systemctl", "stop", unit]
        input_data = (sudo_password + "\n") if sudo_password else None
        res = subprocess.run(cmd, input=input_data, capture_output=True, text=True)
        if res.returncode == 0:
            return True, f"Service {name} stopped"
        err_msg = res.stderr.strip() or "Permission denied or failed to stop"
        return False, f"Failed to stop {name}: {err_msg}"

    elif provider == "docker":
        cid = svc.get("container_id")
        if not cid or not re.match(r'^[a-zA-Z0-9_\-]+$', cid):
            return False, f"Invalid container ID for {name}"
        res = subprocess.run(["docker", "stop", cid], capture_output=True, text=True)
        if res.returncode == 0:
            return True, f"Container {name} stopped"
        return False, f"Failed to stop container {name}: {res.stderr.strip() or 'Error'}"

    return False, f"Unknown service provider: {provider}"

def start_service_safely(svc: Dict[str, Any], sudo_password: Optional[str] = None) -> tuple[bool, str]:
    """Safely start a service without shell eval."""
    provider = svc.get("provider")
    name = svc.get("name", "Unknown")

    if provider == "systemd":
        unit = svc.get("unit")
        if not unit:
            return False, f"Missing unit for {name}"
        cmd = ["sudo", "-S", "systemctl", "start", unit] if sudo_password else ["sudo", "-n", "systemctl", "start", unit]
        input_data = (sudo_password + "\n") if sudo_password else None
        res = subprocess.run(cmd, input=input_data, capture_output=True, text=True)
        if res.returncode == 0:
            return True, f"Service {name} started"
        err_msg = res.stderr.strip() or "Permission denied or failed to start"
        return False, f"Failed to start {name}: {err_msg}"

    elif provider == "docker":
        cid = svc.get("container_id")
        if not cid or not re.match(r'^[a-zA-Z0-9_\-]+$', cid):
            return False, f"Invalid container ID for {name}"
        res = subprocess.run(["docker", "start", cid], capture_output=True, text=True)
        if res.returncode == 0:
            return True, f"Container {name} started"
        return False, f"Failed to start container {name}: {res.stderr.strip() or 'Error'}"

    return False, f"Unknown service provider: {provider}"
