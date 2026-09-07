#!/usr/bin/env python3
"""Probe local LLM inference backends and report which are actually serving.

A listening port is not the same as a working server — trtllm-serve binds its
port well before the model finishes loading, which can take several minutes for
a 120B model. This checks both, so "still loading" is distinguishable from
"crashed".

Usage:
    ./check-backends.py                 # check the defaults below
    ./check-backends.py 8355 8356       # check specific trtllm-serve ports
"""

import json
import socket
import sys
import urllib.error
import urllib.request

DEFAULT_SERVICES = [
    ("TRT-LLM", 8355, "/v1/models"),
    ("TRT-LLM", 8356, "/v1/models"),
    ("Ollama", 11434, "/api/version"),
    ("LM Studio", 1234, "/v1/models"),
]

HOST = "localhost"


def port_is_open(host: str, port: int, timeout: float = 1.0) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        try:
            sock.connect((host, port))
            return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            return False


def probe_api(url: str, timeout: float = 2.0) -> tuple[bool, str]:
    """Return (healthy, detail)."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            if response.status != 200:
                return False, f"HTTP {response.status}"
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                return True, body[:60]
            return True, json.dumps(data)[:60]
    except urllib.error.HTTPError as exc:
        return False, f"HTTP {exc.code}"
    except (urllib.error.URLError, socket.timeout) as exc:
        return False, str(getattr(exc, "reason", exc))


def main(argv: list[str]) -> int:
    if len(argv) > 1:
        services = [("TRT-LLM", int(p), "/v1/models") for p in argv[1:]]
    else:
        services = DEFAULT_SERVICES

    any_healthy = False
    for name, port, path in services:
        label = f"{name} :{port}"
        if not port_is_open(HOST, port):
            print(f"[down]    {label}  — port closed")
            continue

        healthy, detail = probe_api(f"http://{HOST}:{port}{path}")
        if healthy:
            any_healthy = True
            print(f"[ok]      {label}  — {detail}")
        else:
            # Port open but API not answering: almost always still loading.
            print(f"[loading] {label}  — port open, API not ready ({detail})")

    return 0 if any_healthy else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
