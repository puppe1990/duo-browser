"""Opt-in hardware check: always releases the mouse, including assertion failures."""
import json
import selectors
import subprocess
import os


def receive(process: subprocess.Popen) -> str:
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        if not selector.select(timeout=10):
            raise AssertionError("Native helper did not report status within 10 seconds")
    return json.loads(process.stdout.readline())["status"]


def main() -> None:
    process = subprocess.Popen(
        ["native/DuoNative.app/Contents/MacOS/DuoNative"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    try:
        assert "Mouse ainda livre" in receive(process)
        for _ in range(2):
            process.stdin.write("capture\n")
            process.stdin.flush()
            assert "Mouse exclusivo ativo" in receive(process)
            if probe := os.environ.get("DUO_EXCLUSIVE_PROBE"):
                outcome = json.loads(subprocess.check_output([probe], text=True, timeout=10))
                assert outcome["exclusiveBlocked"], f"Foreign process can still open mouse during capture: {outcome}"
            process.stdin.write("release\n")
            process.stdin.flush()
            assert "Mouse liberado" in receive(process)
            if probe := os.environ.get("DUO_EXCLUSIVE_PROBE"):
                outcome = json.loads(subprocess.check_output([probe], text=True, timeout=10))
                assert outcome["opened"], f"Mouse remains locked after release: {outcome}"
        process.stdin.write("quit\n")
        process.stdin.flush()
        process.wait(timeout=5)
        print("PASS: actual USB capture, release and recapture; helper exits cleanly")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


if __name__ == "__main__":
    main()
