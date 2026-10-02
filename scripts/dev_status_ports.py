#!/usr/bin/env python3
"""
Ports discovery adapter and model for dev-status TUI.
Queries ss, netstat, fuser without raw shell output leaking.
Dynamically detects real dev service identity from command-line arguments,
actual process binaries, and project package.json inspection to eliminate
hardcoded/static port conflicts (e.g. 3000 React vs Next.js vs NestJS vs Prisma Studio).
"""
import subprocess
import re
import os
import json
from typing import List, Dict, Any, Optional
from dev_status_process import validate_port, validate_pid, get_pid_resources

KNOWN_INFRA_PORTS = {
    5432: "PostgreSQL",
    5442: "PostgreSQL (Docker)",
    5443: "PostgreSQL (Docker)",
    3306: "MySQL",
    27017: "MongoDB",
    6379: "Redis",
    6390: "Redis (Docker)",
    7700: "MeiliSearch",
    7710: "MeiliSearch (Docker)",
    9000: "MinIO",
    9001: "MinIO Console",
    22: "SSH",
    53: "DNS",
}

def inspect_package_json(directory: str) -> Optional[str]:
    """Inspect package.json dependencies to accurately identify project framework."""
    if not directory or directory == "N/A" or not os.path.exists(directory):
        return None
    pkg_path = os.path.join(directory, "package.json")
    if os.path.isfile(pkg_path):
        try:
            with open(pkg_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                deps = {}
                deps.update(data.get("dependencies", {}))
                deps.update(data.get("devDependencies", {}))
                if "@nestjs/core" in deps or "@nestjs/common" in deps:
                    return "NestJS"
                if "next" in deps:
                    return "Next.js"
                if "@angular/core" in deps:
                    return "Angular"
                if "nuxt" in deps:
                    return "Nuxt"
                if "vite" in deps:
                    return "Vite"
                if "remix" in deps or "@remix-run/dev" in deps:
                    return "Remix"
                if "react" in deps:
                    return "React"
                if "vue" in deps:
                    return "Vue"
                if "svelte" in deps or "@sveltejs/kit" in deps:
                    return "Svelte"
        except Exception:
            pass
    return None

def detect_real_dev_service(proc: str, cmdline: str, project_dir: str = "N/A") -> Optional[str]:
    """
    Intelligently identifies the real framework/service from runtime args,
    executable path, and package.json instead of guessing solely from port numbers.
    """
    c_lower = (cmdline or "").lower()
    p_lower = (proc or "").lower()
    combined = p_lower + " " + c_lower

    # 1. Check explicit command line and arguments
    if "prisma studio" in combined:
        return "Prisma Studio"
    if "@nestjs" in combined or "/nest " in combined or "nest start" in combined:
        return "NestJS"
    if "next dev" in combined or "next start" in combined or "next-server" in combined:
        return "Next.js"
    if "@angular" in combined or "ng serve" in combined or "angular" in combined:
        return "Angular"
    if "vite" in combined:
        return "Vite"
    if "nuxt" in combined:
        return "Nuxt"
    if "remix" in combined:
        return "Remix"
    if "react-scripts" in combined or "react" in combined:
        return "React"
    if "vue-cli" in combined:
        return "Vue"
    if "uvicorn" in combined or "fastapi" in combined:
        return "FastAPI / Uvicorn"
    if "manage.py runserver" in combined or "django" in combined:
        return "Django"
    if "flask" in combined:
        return "Flask"
    if "bun run" in combined:
        return "Bun Dev"

    # 2. Check project package.json if available
    pkg_framework = inspect_package_json(project_dir)
    if pkg_framework:
        return pkg_framework

    # 3. Known infra process binaries
    if "postgres" in p_lower or "postmaster" in p_lower:
        return "PostgreSQL"
    if "mysql" in p_lower or "mariadb" in p_lower:
        return "MySQL"
    if "mongod" in p_lower:
        return "MongoDB"
    if "redis" in p_lower:
        return "Redis"
    if "docker" in p_lower or "containerd" in p_lower:
        return "Docker"
    if "nginx" in p_lower:
        return "Nginx"
    if "apache" in p_lower or "httpd" in p_lower:
        return "Apache"

    return None

def normalize_service_name(proc: str, port: int, cmdline: str = "", project_dir: str = "N/A") -> str:
    """Normalize service name with dynamic analysis first, falling back to infra map."""
    real_dev = detect_real_dev_service(proc, cmdline, project_dir)
    if real_dev:
        return real_dev

    if port in KNOWN_INFRA_PORTS:
        return KNOWN_INFRA_PORTS[port]

    p_lower = (proc or "").lower().strip()
    if p_lower in ("node", "bun"):
        return f"{proc.capitalize()} ({port})"

    return proc if proc and proc != "?" else f"Port {port}"

def get_project_for_pid(pid: int, cmdline: str = "") -> str:
    """Resolve project path/working directory for a PID safely."""
    # 1. Try pwdx
    try:
        res = subprocess.run(["pwdx", str(pid)], capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip():
            parts = res.stdout.strip().split(":", 1)
            if len(parts) == 2 and parts[1].strip():
                return parts[1].strip()
    except Exception:
        pass

    # 2. Try /proc/{pid}/cwd
    try:
        cwd_link = f"/proc/{pid}/cwd"
        if os.path.exists(cwd_link):
            return os.path.realpath(cwd_link)
    except Exception:
        pass

    # 3. Fallback: extract path from cmdline arguments
    if cmdline:
        m = re.search(r'(/home/[^/\s]+(?:/[^/\s]+)*?)/(?:node_modules|\.next|src|apps|libs|package\.json)', cmdline)
        if m:
            return m.group(1)
        m_home = re.search(r'(/home/[^/\s]+/Projects/[^/\s]+(?:/[^/\s]+)?)', cmdline)
        if m_home:
            return m_home.group(1)

    return "N/A"

def discover_ports() -> List[Dict[str, Any]]:
    """
    Structured port discovery using ss, netstat, or fuser.
    Discovers all listening TCP/UDP ports, dynamically extracting process name,
    PID, state, protocol, and real project details without hardcoded name clashes.
    """
    records: Dict[int, Dict[str, Any]] = {}

    # 1. Parse ss -tulnp
    try:
        res = subprocess.run(["ss", "-tulnp"], capture_output=True, text=True)
        if res.returncode == 0:
            for line in res.stdout.splitlines()[1:]:
                parts = line.split()
                if len(parts) >= 5:
                    proto = parts[0].upper()
                    state = parts[1].upper() if proto == "TCP" else "ACTIVE"
                    local_addr = parts[4]
                    port_str = local_addr.rsplit(":", 1)[-1]
                    p_val = validate_port(port_str)
                    if not p_val:
                        continue

                    proc = "?"
                    pid = None
                    if len(parts) >= 6:
                        proc_info = " ".join(parts[5:])
                        m_name = re.search(r'\(\("([^"]+)"', proc_info)
                        if m_name:
                            proc = m_name.group(1)
                        m_pid = re.search(r'pid=(\d+)', proc_info)
                        if m_pid:
                            pid = validate_pid(m_pid.group(1))

                    cmdline = ""
                    if pid:
                        try:
                            ps_res = subprocess.run(["ps", "-p", str(pid), "-o", "comm=,args="], capture_output=True, text=True)
                            if ps_res.returncode == 0 and ps_res.stdout.strip():
                                ps_parts = ps_res.stdout.strip().split(None, 1)
                                if ps_parts:
                                    if proc == "?" or proc == "exe":
                                        proc = ps_parts[0]
                                    cmdline = ps_parts[1] if len(ps_parts) > 1 else ps_parts[0]
                        except Exception:
                            pass

                    proj_dir = get_project_for_pid(pid, cmdline) if pid else "N/A"
                    srv_name = normalize_service_name(proc, p_val, cmdline, proj_dir)
                    res_info = get_pid_resources(pid) if pid else {"cpu": None, "rss_mb": None}
                    records[p_val] = {
                        "port": p_val,
                        "protocol": proto,
                        "address": local_addr,
                        "process": proc,
                        "service": srv_name,
                        "pid": pid,
                        "state": state,
                        "project": proj_dir,
                        "rss_mb": res_info["rss_mb"],
                        "cpu": res_info["cpu"],
                    }
    except Exception:
        pass

    # 2. Check dev ports with fuser if pid missing or port not found
    dev_check_ports = [3000, 3001, 3002, 4200, 5173, 5174, 5555, 8000, 8080, 8081, 5432, 6379, 3306, 27017]
    for p in dev_check_ports:
        if p not in records or records[p]["pid"] is None:
            try:
                res = subprocess.run(["fuser", f"{p}/tcp"], capture_output=True, text=True)
                out = (res.stdout + " " + res.stderr).strip()
                pids = re.findall(r'\b\d+\b', out)
                valid_pids = [int(x) for x in pids if int(x) != p]
                if valid_pids:
                    target_pid = valid_pids[0]
                    p_name = "?"
                    cmdline = ""
                    ps_res = subprocess.run(["ps", "-p", str(target_pid), "-o", "comm=,args="], capture_output=True, text=True)
                    if ps_res.returncode == 0 and ps_res.stdout.strip():
                        ps_parts = ps_res.stdout.strip().split(None, 1)
                        p_name = ps_parts[0] if ps_parts else "?"
                        cmdline = ps_parts[1] if len(ps_parts) > 1 else p_name
                    
                    proj_dir = get_project_for_pid(target_pid, cmdline)
                    srv_name = normalize_service_name(p_name, p, cmdline, proj_dir)
                    res_info = get_pid_resources(target_pid)
                    records[p] = {
                        "port": p,
                        "protocol": "TCP",
                        "address": f"127.0.0.1:{p}",
                        "process": p_name,
                        "service": srv_name,
                        "pid": target_pid,
                        "state": "LISTEN",
                        "project": proj_dir,
                        "rss_mb": res_info["rss_mb"],
                        "cpu": res_info["cpu"],
                    }
            except Exception:
                pass

    result = list(records.values())
    result.sort(key=lambda x: x["port"])
    return result
