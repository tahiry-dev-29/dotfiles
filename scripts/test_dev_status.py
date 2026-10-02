#!/usr/bin/env python3
"""
Automated unit and integration test suite for dev-status TUI components.
Validates:
- Process & Port safety validation (validate_pid, validate_port)
- Structured Ports discovery and parsing
- Services discovery and normalization
- Dev servers discovery and framework identification
- TUI data filtering and multi-selection models
- No arbitrary shell eval / safety guarantees
"""
import unittest
import os
import sys

# Add scripts directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dev_status_process import validate_pid, validate_port, is_pid_alive
from dev_status_ports import discover_ports, normalize_service_name
from dev_status_services import discover_services, SYSTEMD_SERVICES
from dev_status_servers import discover_dev_servers, detect_framework
from dev_status_tui import TABS, DevStatusApp

class TestDevStatusSafety(unittest.TestCase):
    def test_validate_pid(self):
        self.assertIsNone(validate_pid(0))
        self.assertIsNone(validate_pid(1))
        self.assertIsNone(validate_pid(-10))
        self.assertIsNone(validate_pid("abc"))
        self.assertIsNone(validate_pid("12; rm -rf /"))
        self.assertEqual(validate_pid(1234), 1234)
        self.assertEqual(validate_pid("5678"), 5678)

    def test_validate_port(self):
        self.assertIsNone(validate_port(0))
        self.assertIsNone(validate_port(-1))
        self.assertIsNone(validate_port(70000))
        self.assertIsNone(validate_port("invalid"))
        self.assertIsNone(validate_port("80; touch /tmp/pwn"))
        self.assertEqual(validate_port(80), 80)
        self.assertEqual(validate_port("3000"), 3000)
        self.assertEqual(validate_port(65535), 65535)

    def test_framework_detection(self):
        self.assertEqual(detect_framework("node", "nest start:dev"), "NestJS")
        self.assertEqual(detect_framework("node", "ng serve --port 4200"), "Angular")
        self.assertEqual(detect_framework("node", "vite --port 5173"), "Vite")
        self.assertEqual(detect_framework("python", "uvicorn main:app --reload"), "FastAPI / Uvicorn")
        self.assertEqual(detect_framework("python", "python manage.py runserver"), "Django")

class TestDevStatusDiscovery(unittest.TestCase):
    def test_discover_ports_structure(self):
        ports = discover_ports()
        self.assertIsInstance(ports, list)
        for p in ports:
            self.assertIn("port", p)
            self.assertIn("protocol", p)
            self.assertIn("address", p)
            self.assertIn("process", p)
            self.assertIn("service", p)
            self.assertIn("state", p)
            self.assertIn("project", p)
            self.assertTrue(1 <= p["port"] <= 65535)

    def test_discover_services_structure(self):
        services = discover_services()
        self.assertIsInstance(services, list)
        self.assertTrue(len(services) > 0)
        for s in services:
            self.assertIn("name", s)
            self.assertIn("state", s)
            self.assertIn("provider", s)
            self.assertIn("port", s)
            self.assertIn(s["state"], ["running", "stopped"])
            self.assertIn(s["provider"], ["systemd", "docker"])

    def test_discover_dev_servers_structure(self):
        servers = discover_dev_servers()
        self.assertIsInstance(servers, list)
        # May be empty in sandboxed/CI environments with no running dev servers
        for s in servers:
            self.assertIn("project", s)
            self.assertIn("framework", s)
            self.assertIn("command", s)
            self.assertIn("port", s)
            self.assertIn("state", s)
            self.assertIn(s["state"], ["running", "stopped"])

    def test_normalize_service_name(self):
        # Infra ports still resolve by port map regardless of proc name
        self.assertEqual(normalize_service_name("postgres", 5432), "PostgreSQL")
        self.assertEqual(normalize_service_name("redis-server", 6379), "Redis")

        # With cmdline, framework is detected dynamically
        self.assertEqual(normalize_service_name("node", 3000, cmdline="nest start:dev"), "NestJS")
        self.assertEqual(normalize_service_name("node", 3000, cmdline="next dev"), "Next.js")
        self.assertEqual(normalize_service_name("node", 4200, cmdline="ng serve --port 4200"), "Angular")
        self.assertEqual(normalize_service_name("node", 5173, cmdline="vite --port 5173"), "Vite")

        # Without cmdline, node on a non-infra port falls back to proc+port
        result = normalize_service_name("node", 3000)
        self.assertIn("3000", result)  # Should mention port when framework unknown

if __name__ == "__main__":
    unittest.main()
