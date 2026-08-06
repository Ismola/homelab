#!/usr/bin/env python3
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


API_URL = "https://api.cloudflare.com/client/v4/graphql"
SECRET_DIR = "/var/run/secrets/cloudflare"
REFRESH_INTERVAL = int(os.getenv("REFRESH_INTERVAL_SECONDS", "900"))
ENDPOINTS = [value.strip() for value in os.getenv("PUBLIC_ENDPOINTS", "").split(",") if value.strip()]
HOSTNAMES = sorted(
    {
        urllib.parse.urlparse(endpoint).hostname
        for endpoint in ENDPOINTS
        if urllib.parse.urlparse(endpoint).hostname
    }
)
WINDOWS = {"1h": timedelta(hours=1), "24h": timedelta(hours=24)}

QUERY = """
query TrafficByHostname($zoneTag: string, $start: Time, $end: Time) {
  viewer {
    zones(filter: {zoneTag: $zoneTag}) {
      byHostname: httpRequestsAdaptiveGroups(
        limit: 1000
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        count
        sum {
          visits
          edgeResponseBytes
        }
        dimensions {
          clientRequestHTTPHost
        }
      }
      byCountry: httpRequestsAdaptiveGroups(
        limit: 1000
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        sum {
          visits
        }
        dimensions {
          clientCountryName
          clientRequestHTTPHost
        }
      }
    }
  }
}
"""

state_lock = threading.Lock()
metric_samples = []
exporter_up = 0
last_success = 0.0
last_error = "Waiting for the first Cloudflare Analytics query"


def read_secret(name):
    try:
        with open(os.path.join(SECRET_DIR, name), encoding="utf-8") as secret_file:
            return secret_file.read().strip()
    except FileNotFoundError:
        return ""


def query_cloudflare(token, zone_id, start, end):
    payload = json.dumps(
        {
            "query": QUERY,
            "variables": {
                "zoneTag": zone_id,
                "start": start.isoformat().replace("+00:00", "Z"),
                "end": end.isoformat().replace("+00:00", "Z"),
            },
        }
    ).encode()
    request = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "homelab-cloudflare-analytics-exporter/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:500]
        raise RuntimeError(f"Cloudflare API returned HTTP {error.code}: {detail}") from error

    if result.get("errors"):
        messages = "; ".join(error.get("message", str(error)) for error in result["errors"])
        raise RuntimeError(messages)

    zones = result.get("data", {}).get("viewer", {}).get("zones", [])
    if not zones:
        raise RuntimeError("Cloudflare returned no analytics data for the configured zone")
    return zones[0]


def collect_window(token, zone_id, window_name, duration):
    end = datetime.now(timezone.utc).replace(microsecond=0)
    data = query_cloudflare(token, zone_id, end - duration, end)
    host_values = {
        hostname: {"requests": 0, "visits": 0, "bytes": 0}
        for hostname in HOSTNAMES
    }

    for group in data.get("byHostname", []):
        hostname = group.get("dimensions", {}).get("clientRequestHTTPHost", "")
        if hostname not in host_values:
            continue
        totals = group.get("sum") or {}
        host_values[hostname] = {
            "requests": group.get("count", 0),
            "visits": totals.get("visits", 0),
            "bytes": totals.get("edgeResponseBytes", 0),
        }

    samples = []
    for hostname, values in host_values.items():
        labels = {"hostname": hostname, "window": window_name}
        samples.extend(
            [
                ("cloudflare_analytics_requests", labels, values["requests"]),
                ("cloudflare_analytics_visits", labels, values["visits"]),
                ("cloudflare_analytics_data_transfer_bytes", labels, values["bytes"]),
            ]
        )

    for group in data.get("byCountry", []):
        dimensions = group.get("dimensions", {})
        hostname = dimensions.get("clientRequestHTTPHost", "")
        if hostname not in host_values:
            continue
        country = dimensions.get("clientCountryName", "") or "unknown"
        samples.append(
            (
                "cloudflare_analytics_visits_by_country",
                {"hostname": hostname, "country": country, "window": window_name},
                (group.get("sum") or {}).get("visits", 0),
            )
        )
    return samples


def refresh():
    global exporter_up, last_error, last_success, metric_samples
    token = read_secret("api-token")
    zone_id = read_secret("zone-id")
    if not token or not zone_id:
        with state_lock:
            exporter_up = 0
            last_error = "The cloudflare-analytics Secret must contain api-token and zone-id"
        return

    try:
        samples = []
        for window_name, duration in WINDOWS.items():
            samples.extend(collect_window(token, zone_id, window_name, duration))
        with state_lock:
            metric_samples = samples
            exporter_up = 1
            last_success = time.time()
            last_error = ""
    except (OSError, RuntimeError, urllib.error.URLError) as error:
        with state_lock:
            exporter_up = 0
            last_error = str(error)


def refresh_loop():
    while True:
        refresh()
        time.sleep(REFRESH_INTERVAL)


def escape_label(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def format_sample(name, labels, value):
    label_text = ",".join(f'{key}="{escape_label(label)}"' for key, label in sorted(labels.items()))
    return f"{name}{{{label_text}}} {float(value)}"


def render_metrics():
    with state_lock:
        samples = list(metric_samples)
        up = exporter_up
        success_timestamp = last_success
        error = last_error

    lines = [
        "# HELP cloudflare_analytics_up Whether the last Cloudflare Analytics query succeeded.",
        "# TYPE cloudflare_analytics_up gauge",
        f"cloudflare_analytics_up {up}",
        "# HELP cloudflare_analytics_last_success_timestamp_seconds Unix timestamp of the last successful query.",
        "# TYPE cloudflare_analytics_last_success_timestamp_seconds gauge",
        f"cloudflare_analytics_last_success_timestamp_seconds {success_timestamp}",
        "# HELP cloudflare_analytics_requests Estimated eyeball HTTP requests in the rolling window.",
        "# TYPE cloudflare_analytics_requests gauge",
        "# HELP cloudflare_analytics_visits Cloudflare visits in the rolling window; this is not a unique-person count.",
        "# TYPE cloudflare_analytics_visits gauge",
        "# HELP cloudflare_analytics_data_transfer_bytes Edge response bytes in the rolling window.",
        "# TYPE cloudflare_analytics_data_transfer_bytes gauge",
        "# HELP cloudflare_analytics_visits_by_country Cloudflare visits grouped by request country.",
        "# TYPE cloudflare_analytics_visits_by_country gauge",
    ]
    lines.extend(format_sample(name, labels, value) for name, labels, value in samples)
    if error:
        lines.extend(
            [
                "# HELP cloudflare_analytics_last_error_info Last exporter error as an informational label.",
                "# TYPE cloudflare_analytics_last_error_info gauge",
                format_sample("cloudflare_analytics_last_error_info", {"message": error[:300]}, 1),
            ]
        )
    return "\n".join(lines) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            body = render_metrics().encode()
            status = 200
        elif self.path == "/healthz":
            body = b"ok\n"
            status = 200
        else:
            body = b"not found\n"
            status = 404
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, message_format, *args):
        return


if __name__ == "__main__":
    threading.Thread(target=refresh_loop, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", 9101), MetricsHandler).serve_forever()
