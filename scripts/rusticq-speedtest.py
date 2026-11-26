#!/usr/bin/env python3
"""Supported CLI adapter. Emits only normalized metrics, never raw CLI output.

Ookla speedtest: JSONL bandwidth is bytes/s. sivel speedtest-cli: JSON is bits/s.
No installation, license acceptance, shell interpolation or result persistence.
"""
import argparse
import json
import math
import os
import selectors
import shutil
import signal
import subprocess
import sys
import time

TEST_TIMEOUT = 120
MAX_LINE = 64 * 1024


class TestError(Exception):
    pass


class Cancelled(Exception):
    pass


def emit(**event):
    print(json.dumps(event, allow_nan=False), flush=True)


def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
        raise TestError("The backend returned invalid measurements. Retry the test.")
    return value


def detect_backend():
    fallback = None
    for executable in ("speedtest", "speedtest-cli"):
        path = shutil.which(executable)
        if not path:
            continue
        try:
            version = subprocess.run([path, "--version"], stdin=subprocess.DEVNULL,
                                     capture_output=True, text=True, timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            continue
        text = (version.stdout + version.stderr).lower()
        if version.returncode == 0 and "ookla" in text:
            return "ookla", path
        if version.returncode == 0 and "speedtest-cli" in text:
            fallback = ("sivel", path)
    return fallback


def command_for(backend, path):
    if backend == "ookla":
        return [path, "--format=jsonl", "--progress=yes"]
    return [path, "--json", "--secure", "--timeout", "10", "--no-pre-allocate"]


def parse_event(data, backend):
    if not isinstance(data, dict):
        raise TestError("The backend returned invalid results. Retry the test.")
    if backend == "sivel":
        return dict(phase="complete", progress=1, pingMs=number(data.get("ping")),
                    downloadMbps=number(data.get("download")) / 1e6,
                    uploadMbps=number(data.get("upload")) / 1e6)
    kind = data.get("type")
    if kind == "result":
        try:
            return dict(phase="complete", progress=1,
                        pingMs=number(data["ping"]["latency"]),
                        downloadMbps=number(data["download"]["bandwidth"]) * 8 / 1e6,
                        uploadMbps=number(data["upload"]["bandwidth"]) * 8 / 1e6)
        except (KeyError, TypeError):
            raise TestError("The backend returned incomplete results. Retry the test.") from None
    if kind in ("ping", "download", "upload"):
        sample = data.get(kind)
        if not isinstance(sample, dict):
            raise TestError("The backend returned invalid progress. Retry the test.")
        phase = "ping" if kind == "ping" else kind
        event = dict(phase=phase)
        if kind == "ping":
            if "latency" in sample:
                event["pingMs"] = number(sample["latency"])
        elif "bandwidth" in sample:
            event[kind + "Mbps"] = number(sample["bandwidth"]) * 8 / 1e6
        if "progress" in sample:
            progress = min(1, number(sample["progress"]))
            base, weight = {"ping": (0, .1), "download": (.1, .45), "upload": (.55, .45)}[kind]
            event["progress"] = base + progress * weight
        return event
    if kind in ("log", "error") and (kind == "error" or data.get("level") == "error"):
        raise TestError(failure_message(str(data.get("message", ""))))
    return None  # init/server information and non-error logs contain no measurements


def failure_message(text):
    text = text.lower()
    if any(word in text for word in ("license", "licence", "gdpr", "eula", "terms of use")):
        return "Ookla setup required. Run speedtest in a terminal to review its terms, then retry here."
    if any(word in text for word in ("network", "connect", "resolve", "socket", "server", "configuration")):
        return "Cannot reach a test server. Check your connection or Wi-Fi login portal and retry."
    return "Speed test failed. Check the backend in a terminal and retry."


def terminate(proc):
    # The backend gets its own process group, including any worker children.
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=.7)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()


def run_backend(backend, path, report=emit, timeout=TEST_TIMEOUT):
    report(phase="preparing", backend=backend, progress=0)
    proc = subprocess.Popen(command_for(backend, path), stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    buffers = {proc.stdout: b"", proc.stderr: b""}
    diagnostic = ""
    result = None
    deadline = time.monotonic() + timeout

    def consume(line, stream):
        nonlocal diagnostic, result
        text = line.decode("utf-8", errors="replace").strip()
        if not text:
            return
        if stream is proc.stderr:
            diagnostic = (diagnostic + " " + text)[-8192:]
            return
        try:
            data = json.loads(text)
        except ValueError:
            # An uninitialized Ookla installation prints a multi-line license
            # notice. Read the whole notice with stdin closed before classifying
            # the failure; its first line may only be a decorative separator.
            diagnostic = (diagnostic + " " + text)[-8192:]
            return
        event = parse_event(data, backend)
        if event:
            if event["phase"] == "complete":
                result = event  # Commit only after the backend exits successfully.
            else:
                report(**event)

    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            selector.register(proc.stderr, selectors.EVENT_READ)
            while selector.get_map():
                if time.monotonic() >= deadline:
                    raise TestError("Speed test timed out. Check your connection and retry.")
                for key, _ in selector.select(.2):
                    stream = key.fileobj
                    block = os.read(stream.fileno(), 8192)
                    buffers[stream] += block
                    if len(buffers[stream]) > MAX_LINE:
                        raise TestError("The backend returned too much output. Check its version.")
                    while b"\n" in buffers[stream]:
                        line, buffers[stream] = buffers[stream].split(b"\n", 1)
                        consume(line, stream)
                    if not block:
                        consume(buffers[stream], stream)
                        buffers[stream] = b""
                        selector.unregister(stream)
            remaining = max(.01, deadline - time.monotonic())
            try:
                code = proc.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                raise TestError("Speed test timed out. Check your connection and retry.") from None
            if code != 0:
                raise TestError(failure_message(diagnostic))
            if result is None:
                raise TestError(failure_message(diagnostic) if diagnostic else "The backend stopped without results. Retry the test.")
            report(**result)
    finally:
        terminate(proc)
        proc.stdout.close()
        proc.stderr.close()


def cancel(signum, frame):
    raise Cancelled


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", action="store_true", help="Check installed CLI only; no test traffic")
    args = parser.parse_args(argv)
    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    try:
        backend = detect_backend()
        if not backend:
            emit(phase="missing", message="Install Ookla Speedtest CLI (speedtest) or speedtest-cli to test your connection.")
            return 2
        if args.probe:
            emit(phase="ready", backend=backend[0])
            return 0
        run_backend(*backend)
        return 0
    except Cancelled:
        emit(phase="cancelled")
        return 130
    except (TestError, OSError) as error:
        emit(phase="error", message=str(error) if isinstance(error, TestError)
             else "Could not start the speed test backend. Check its installation and retry.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
