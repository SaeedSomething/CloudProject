#!/usr/bin/env python3
"""
HPA Stress Testing Script for ArvanCloud Microservices
This script generates load on all microservices to trigger HPA scaling for demonstration purposes.
"""

import asyncio
import aiohttp
import time
import argparse
import json
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
import threading


class HPAStressTest:
    def __init__(
        self,
        base_url="https://nginx-lb-c9a4c1e532-ingress-nginx.apps.ir-central1.arvancaas.ir",
        duration=300,
        concurrent_requests=50,
    ):
        """
        Initialize the stress test

        Args:
            base_url: Base URL for the services (default: https://nginx-lb-c9a4c1e532-ingress-nginx.apps.ir-central1.arvancaas.ir/)
            duration: Test duration in seconds (default: 5 minutes)
            concurrent_requests: Number of concurrent requests per endpoint
        """
        self.base_url = base_url.rstrip("/")
        self.duration = duration
        self.concurrent_requests = concurrent_requests
        self.stats = {
            "auth": {"total": 0, "success": 0, "errors": 0},
            "core": {"total": 0, "success": 0, "errors": 0},
            "manage": {"total": 0, "success": 0, "errors": 0},
            "health": {"total": 0, "success": 0, "errors": 0},
        }
        self.running = True

        # Service endpoints configuration
        self.endpoints = {
            "auth": [
                "/auth/user/login",
                "/auth/user/register",
                "/auth/user",
                # "/auth/validate",
                # "/auth/health",
            ],
            "core": [
                "/core/notifications/send",
                "/core/notifications",
                "/core/mail/configs",
                "/core/docs/api-docs",
                "/core/health",
            ],
            "manage": [
                "/manage/auth/users",
                # "/manage/notifications",
                # "/manage/statistics",
                # "/manage/reports",
                "/manage/auth/user?identifier=asd",
                "/manage/health",
            ],
            "health": ["/health"],
        }

        # Sample payloads for POST requests
        self.payloads = {
            "auth_login": {
                "username": f"stressuser_{int(time.time() * 1000) % 10000}",
                "password": "ComplexPassword123!@#$%^&*()" * 3,
            },
            "auth_register": {
                "username": f"user_{int(time.time() * 1000000) % 100000}",
                "Email": f"stress_{int(time.time() * 1000000) % 100000}@loadtest.com",
                "Password": "VeryComplexPassword123!@#$%^&*()" * 5,
                "firstName": "LoadTest" * 10,
                "lastName": "User" * 10,
            },
            "core_notification": {
                "title": "Load Test Notification " + "A" * 100,
                "message": ("CPU-intensive notification payload. " * 50),
                "recipients": [f"recipient{i}@test.com" for i in range(20)],
                "type": "EMAIL",
                "template": "complex_template",
                "attachments": [f"file_{i}.pdf" for i in range(10)],
            },
        }

    async def make_request(self, session, url, method="GET", payload=None):
        """Make an HTTP request and handle response"""
        try:
            headers = {"Content-Type": "application/json"}

            if method == "GET":
                async with session.get(url, headers=headers, timeout=10) as response:
                    await response.text()
                    return response.status == 200
            elif method == "POST":
                async with session.post(
                    url, json=payload, headers=headers, timeout=10
                ) as response:
                    await response.text()
                    return response.status in [200, 201, 202]

        except Exception as e:
            print(f"Request error for {url}: {str(e)}")
            return False

    async def stress_service(self, session, service_name, semaphore):
        """Generate load on a specific service"""
        endpoints = self.endpoints[service_name]

        while self.running:
            async with semaphore:
                for endpoint in endpoints:
                    if not self.running:
                        break

                    url = f"{self.base_url}{endpoint}"

                    # Determine request method and payload
                    method = "GET"
                    payload = None

                    if "login" in endpoint:
                        method = "POST"
                        payload = self.payloads["auth_login"].copy()
                        # Unique data for each request
                        payload["username"] = (
                            f"stress_{int(time.time() * 1000) % 10000}"
                        )
                    elif "register" in endpoint:
                        method = "POST"
                        payload = self.payloads["auth_register"].copy()
                        # Update with unique data to avoid conflicts
                        timestamp = int(time.time() * 1000000) % 100000
                        payload["username"] = f"user_{timestamp}"
                        payload["Email"] = f"stress_{timestamp}@loadtest.com"
                    elif "send" in endpoint or (
                        "notifications" in endpoint and service_name == "core"
                    ):
                        method = "POST"
                        payload = self.payloads["core_notification"].copy()
                        # Make each notification unique and CPU-intensive
                        payload["title"] = (
                            f"Load Test {int(time.time() * 1000)} " + "X" * 200
                        )
                        payload["message"] = (
                            f"CPU intensive payload {time.time()} " * 100
                        )
                    elif service_name == "manage" and (
                        "users" in endpoint
                        or "statistics" in endpoint
                        or "reports" in endpoint
                    ):
                        # Some manage endpoints might accept POST for data processing
                        if "statistics" in endpoint or "reports" in endpoint:
                            method = "POST"
                            payload = {
                                "startDate": "2024-01-01",
                                "endDate": "2024-12-31",
                                "filters": {"complex": "data" * 50},
                                "aggregations": [f"metric_{i}" for i in range(20)],
                            }

                    # Make the request
                    self.stats[service_name]["total"] += 1
                    success = await self.make_request(session, url, method, payload)

                    if success:
                        self.stats[service_name]["success"] += 1
                    else:
                        self.stats[service_name]["errors"] += 1

                    # Small delay to prevent overwhelming (reduced for more aggressive testing)
                    await asyncio.sleep(0.01)

    async def run_stress_test(self):
        """Run the main stress test"""
        print(f"🚀 Starting HPA Stress Test")
        print(f"📊 Target: {self.base_url}")
        print(f"⏱️  Duration: {self.duration} seconds")
        print(f"🔥 Concurrent requests per service: {self.concurrent_requests}")
        print(f"📈 This should trigger HPA scaling with the new thresholds!")
        print("-" * 60)

        # Semaphore to limit concurrent requests
        semaphore = asyncio.Semaphore(self.concurrent_requests)

        async with aiohttp.ClientSession() as session:
            # Create tasks for each service
            tasks = []

            for service_name in self.endpoints.keys():
                # Create multiple concurrent tasks per service
                for _ in range(self.concurrent_requests):
                    task = asyncio.create_task(
                        self.stress_service(session, service_name, semaphore)
                    )
                    tasks.append(task)

            # Let tests run for specified duration
            await asyncio.sleep(self.duration)

            # Stop all tasks
            self.running = False

            # Wait a bit for tasks to finish gracefully
            await asyncio.sleep(2)

            # Cancel remaining tasks
            for task in tasks:
                if not task.done():
                    task.cancel()

            # Wait for all tasks to complete
            await asyncio.gather(*tasks, return_exceptions=True)

    def print_stats(self):
        """Print test statistics"""
        print("\n" + "=" * 60)
        print("🎯 HPA STRESS TEST RESULTS")
        print("=" * 60)

        total_requests = 0
        total_success = 0
        total_errors = 0

        for service, stats in self.stats.items():
            success_rate = (
                (stats["success"] / stats["total"]) * 100 if stats["total"] > 0 else 0
            )
            print(f"📱 {service.upper()} Service:")
            print(f"   ├── Total Requests: {stats['total']}")
            print(f"   ├── Successful: {stats['success']}")
            print(f"   ├── Errors: {stats['errors']}")
            print(f"   └── Success Rate: {success_rate:.1f}%")
            print()

            total_requests += stats["total"]
            total_success += stats["success"]
            total_errors += stats["errors"]

        overall_success_rate = (
            (total_success / total_requests) * 100 if total_requests > 0 else 0
        )

        print(f"📊 OVERALL SUMMARY:")
        print(f"   ├── Total Requests: {total_requests}")
        print(f"   ├── Successful: {total_success}")
        print(f"   ├── Errors: {total_errors}")
        print(f"   └── Success Rate: {overall_success_rate:.1f}%")
        print()
        print("🔍 Check your Kubernetes dashboard to see HPA scaling in action!")
        print("💡 Use: kubectl get hpa -A --watch")


def monitor_hpa(duration):
    """Monitor HPA status during test (runs in separate thread)"""
    import subprocess
    import time

    print("📊 Starting HPA monitoring...")
    start_time = time.time()

    while time.time() - start_time < duration:
        try:
            result = subprocess.run(
                ["kubectl", "get", "hpa", "-A", "--no-headers"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                print(f"\n⚡ HPA Status ({datetime.now().strftime('%H:%M:%S')}):")
                for line in lines:
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 7:
                            namespace = parts[0]
                            name = parts[1]
                            current = parts[6] if parts[6] != "<unknown>" else "?"
                            min_pods = parts[4]
                            max_pods = parts[5]
                            print(
                                f"  📈 {namespace}/{name}: {current}/{min_pods}-{max_pods}"
                            )
        except Exception as e:
            print(f"HPA monitoring error: {e}")

        time.sleep(10)  # Check every 10 seconds


async def main():
    parser = argparse.ArgumentParser(
        description="HPA Stress Test for ArvanCloud Microservices"
    )
    parser.add_argument(
        "--url",
        default="https://nginx-lb-c9a4c1e532-ingress-nginx.apps.ir-central1.arvancaas.ir/",
        help="Base URL for services",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=300,
        help="Test duration in seconds (default: 300)",
    )
    parser.add_argument(
        "--concurrent",
        type=int,
        default=30,
        help="Concurrent requests per service (default: 30)",
    )
    parser.add_argument(
        "--monitor-hpa", action="store_true", help="Monitor HPA status during test"
    )

    args = parser.parse_args()

    # Create stress test instance
    stress_test = HPAStressTest(
        base_url=args.url, duration=args.duration, concurrent_requests=args.concurrent
    )

    # Start HPA monitoring in separate thread if requested
    monitor_thread = None
    if args.monitor_hpa:
        monitor_thread = threading.Thread(
            target=monitor_hpa,
            args=(args.duration + 30,),  # Monitor a bit longer than test
            daemon=True,
        )
        monitor_thread.start()

    try:
        # Run the stress test
        await stress_test.run_stress_test()

        # Print results
        stress_test.print_stats()

    except KeyboardInterrupt:
        print("\n🛑 Test interrupted by user")
        stress_test.running = False
    except Exception as e:
        print(f"\n❌ Test failed: {e}")

    print("\n🏁 Stress test completed!")


if __name__ == "__main__":
    # Install required packages if not available
    try:
        import aiohttp
    except ImportError:
        print("Installing required packages...")
        import subprocess

        subprocess.check_call(["pip", "install", "aiohttp"])
        import aiohttp

    asyncio.run(main())
