#!/usr/bin/env python3
"""Utility for polling HTTP endpoints until they report healthy."""

from __future__ import annotations

import argparse
import sys
import time
import urllib.error
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Poll one or more HTTP endpoints until they respond successfully. "
            "A response status in the 200-399 range is treated as healthy."
        )
    )
    parser.add_argument(
        "urls",
        metavar="URL",
        nargs="+",
        help="HTTP endpoint(s) to poll",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=24,
        help="Number of attempts per URL (default: %(default)s)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=5.0,
        help="Seconds to wait between attempts (default: %(default)s)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Per-request timeout in seconds (default: %(default)s)",
    )
    return parser.parse_args()


def request_ok(url: str, timeout: float) -> bool:
    request = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
            return 200 <= response.status < 400
    except urllib.error.HTTPError as exc:
        print(f"{url} responded with HTTP {exc.code}")
        return False
    except urllib.error.URLError as exc:
        print(f"{url} not reachable: {exc.reason}")
        return False


def poll_url(url: str, retries: int, delay: float, timeout: float) -> bool:
    for attempt in range(1, retries + 1):
        if request_ok(url, timeout):
            print(f"{url} healthy after {attempt} attempt(s)")
            return True
        if attempt == retries:
            break
        time.sleep(delay)
    print(f"{url} failed health check after {retries} attempt(s)")
    return False


def main() -> int:
    args = parse_args()
    all_healthy = True
    for url in args.urls:
        healthy = poll_url(url=url, retries=args.retries, delay=args.delay, timeout=args.timeout)
        all_healthy = all_healthy and healthy
    return 0 if all_healthy else 1


if __name__ == "__main__":
    sys.exit(main())
