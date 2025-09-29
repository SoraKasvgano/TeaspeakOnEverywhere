#!/usr/bin/env python3
import os
import sys
import subprocess
import argparse

def run_cmd(cmd):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=True)

def main():
    parser = argparse.ArgumentParser(description="Build TeaSpeak multi-arch images")
    parser.add_argument("-u", "--username", required=True, help="Docker Hub username")
    parser.add_argument("-v", "--version", default="1.4.22", help="Version")
    args = parser.parse_args()
    
    username = args.username
    version = args.version
    platforms = "linux/amd64,linux/arm64,linux/arm/v7"
    
    print(f"Building multi-arch images for {username}/teaspeak")
    
    # Setup buildx
    try:
        run_cmd(["docker", "buildx", "inspect", "teaspeak-builder"])
    except:
        run_cmd(["docker", "buildx", "create", "--name", "teaspeak-builder", "--use"])
    
    run_cmd(["docker", "buildx", "use", "teaspeak-builder"])
    run_cmd(["docker", "buildx", "inspect", "--bootstrap"])
    
    # Build and push version tag
    version_tag = f"{username}/teaspeak:{version}"
    run_cmd([
        "docker", "buildx", "build",
        "--platform", platforms,
        "--no-cache",
        "-t", version_tag,
        "-f", "Dockerfile",
        "--build-arg", f"TEA_VERSION={version}",
        "--push",
        "."
    ])
    
    # Create latest manifest (KEY FEATURE: merges different arch tags to latest)
    latest_tag = f"{username}/teaspeak:latest"
    run_cmd([
        "docker", "buildx", "imagetools", "create",
        "-t", latest_tag,
        version_tag
    ])
    
    print(f"✅ Success! Multi-arch image: {latest_tag}")
    print("🏗️ Architectures: AMD64, ARM64, ARM32v7")
    print(f"📋 Inspect: docker buildx imagetools inspect {latest_tag}")

if __name__ == "__main__":
    main()