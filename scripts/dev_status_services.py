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

def _has_socket_unit(unit: str, sudo_password: Optional[str] = None) -> bool:
    """Check if a companion .socket unit exists and is active."""
    socket_unit = f"{unit}.socket"
    try:
        res = subprocess.run(
            ["systemctl", "is-active", socket_unit],
            capture_output=True, text=True
        )
        return res.stdout.strip() == "active"
    except Exception:
        return False

def _run_systemctl(action: str, unit: str, sudo_password: Optional[str] = None) -> tuple[bool, str]:
    """Run systemctl <action> <unit> safely with optional sudo."""
    if sudo_password:
        cmd = ["sudo", "-S", "systemctl", action, unit]
        input_data = sudo_password + "\n"
    else:
        cmd = ["sudo", "-n", "systemctl", action, unit]
        input_data = None
    res = subprocess.run(cmd, input=input_data, capture_output=True, text=True)
    if res.returncode == 0:
        return True, ""
    return False, res.stderr.strip() or "Permission denied"

def stop_service_safely(svc: Dict[str, Any], sudo_password: Optional[str] = None) -> tuple[bool, str]:
    """
    Safely stop a systemd or docker service.

    For systemd: also stops the companion .socket unit (if active) to prevent
    socket-activated services (like docker.socket) from auto-restarting the service.
    """
    provider = svc.get("provider")
    name = svc.get("name", "Unknown")

    if provider == "systemd":
        unit = svc.get("unit")
        if not unit:
            return False, f"Missing unit for {name}"

        # Stop the service itself
        ok, err = _run_systemctl("stop", unit, sudo_password)
        if not ok:
            return False, f"Failed to stop {name}: {err}"

        # Also stop companion .socket unit if active (prevents socket-activation revival)
        if _has_socket_unit(unit):
            _run_systemctl("stop", f"{unit}.socket", sudo_password)

        return True, f"Service {name} stopped"

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
    """
    Safely start a systemd or docker service.

    For systemd: also starts the companion .socket unit if one exists
    (e.g. docker.socket), ensuring the service is fully operational.
    """
    provider = svc.get("provider")
    name = svc.get("name", "Unknown")

    if provider == "systemd":
        unit = svc.get("unit")
        if not unit:
            return False, f"Missing unit for {name}"

        # Start the socket unit first if it exists (ensures socket-activation works)
        socket_unit = f"{unit}.socket"
        res_check = subprocess.run(
            ["systemctl", "list-unit-files", socket_unit, "--no-legend"],
            capture_output=True, text=True
        )
        if socket_unit in res_check.stdout:
            _run_systemctl("start", socket_unit, sudo_password)

        # Start the service
        ok, err = _run_systemctl("start", unit, sudo_password)
        if ok:
            return True, f"Service {name} started"
        return False, f"Failed to start {name}: {err}"

    elif provider == "docker":
        cid = svc.get("container_id")
        if not cid or not re.match(r'^[a-zA-Z0-9_\-]+$', cid):
            return False, f"Invalid container ID for {name}"
        res = subprocess.run(["docker", "start", cid], capture_output=True, text=True)
        if res.returncode == 0:
            return True, f"Container {name} started"
        return False, f"Failed to start container {name}: {res.stderr.strip() or 'Error'}"

    return False, f"Unknown service provider: {provider}"
