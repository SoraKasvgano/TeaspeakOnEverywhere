#!/usr/bin/env python3
import os
import subprocess
import sys

def run_command(cmd, check_output=False):
    """Run a command and handle errors"""
    print(f"Running: {' '.join(cmd)}")
    try:
        if check_output:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        else:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"Error running command: {result.stderr}")
                return False
            return True
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {e}")
        print(f"Error output: {e.stderr}")
        return False

def setup_buildx():
    """Setup docker buildx for multi-architecture builds"""
    print("Setting up Docker Buildx...")
    
    # Create a new builder instance
    if not run_command(['docker', 'buildx', 'create', '--name', 'teaspeak-builder', '--use']):
        print("Failed to create buildx builder, trying to use existing one...")
        run_command(['docker', 'buildx', 'use', 'teaspeak-builder'])
    
    # Bootstrap the builder
    run_command(['docker', 'buildx', 'inspect', '--bootstrap'])

def main():
    print("Building pre-downloaded images only")
    
    tag_name = input('Enter tag name: ')
    if not tag_name:
        print("Tag name is required!")
        sys.exit(1)
    
    # Ask if user wants to push to registry
    push_input = input('Push to Docker Hub? (requires login) [y/N] ').lower()
    push_to_registry = push_input in ['y', 'yes']
    
    # Get Docker Hub username
    docker_username = "teaspeak"  # Default
    if push_to_registry:
        username_input = input('Enter your Docker Hub username [teaspeak]: ').strip()
        if username_input:
            docker_username = username_input
        print(f"Using Docker Hub username: {docker_username}")
    
    # Set current workdir
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    print("Building TeaSpeak multi-architecture images...")
    
    # Setup buildx
    setup_buildx()
    
    # Build configurations
    architectures = {
        'arm32v7': 'linux/arm/v7',
        'arm64v8': 'linux/arm64/v8',
        'x86_64': 'linux/amd64'
    }
    
    # Build pre-downloaded images only
    print("\nBuilding pre-downloaded images...")
    for arch, platform in architectures.items():
        dockerfile = f'Dockerfile.{arch}-predownloaded'
        image_tag = f'{docker_username}/teaspeak-server:{arch}-{tag_name}'
        
        print(f"\nBuilding {arch} pre-downloaded image for platform {platform}...")
        
        build_cmd = [
            'docker', 'buildx', 'build',
            '--platform', platform,
            '--no-cache',
            '-t', image_tag,
            '-f', dockerfile,
            '.'
        ]
        
        if push_to_registry:
            build_cmd.append('--push')
        else:
            build_cmd.extend(['--load'])
        
        if not run_command(build_cmd):
            print(f"Failed to build {arch} pre-downloaded image")
            continue
        
        print(f"Successfully built {arch} pre-downloaded image: {image_tag}")
    
    # Create manifests only if pushing to registry
    if push_to_registry:
        print("\nCreating manifests...")
        
        # Pre-downloaded manifest
        predownloaded_manifest_images = [
            f'{docker_username}/teaspeak-server:arm32v7-{tag_name}',
            f'{docker_username}/teaspeak-server:arm64v8-{tag_name}',
            f'{docker_username}/teaspeak-server:x86_64-{tag_name}'
        ]
        
        print("Creating latest manifest...")
        if run_command(['docker', 'manifest', 'create', f'{docker_username}/teaspeak-server:latest'] + predownloaded_manifest_images):
            run_command(['docker', 'manifest', 'push', '--purge', f'{docker_username}/teaspeak-server:latest'])
        
        # Create unified latest manifest that includes all architectures
        print("Creating unified latest manifest...")
        latest_manifest_cmd = [
            'docker', 'manifest', 'create', 
            f'{docker_username}/teaspeak-server:latest'
        ] + predownloaded_manifest_images
        
        if run_command(latest_manifest_cmd):
            # Annotate each architecture
            for arch, platform in architectures.items():
                annotate_cmd = [
                    'docker', 'manifest', 'annotate',
                    f'{docker_username}/teaspeak-server:latest',
                    f'{docker_username}/teaspeak-server:{arch}-{tag_name}',
                    '--arch', arch.replace('x86_64', 'amd64').replace('arm64v8', 'arm64').replace('arm32v7', 'arm'),
                    '--os', 'linux'
                ]
                run_command(annotate_cmd)
            
            # Push the unified manifest
            run_command(['docker', 'manifest', 'push', '--purge', f'{docker_username}/teaspeak-server:latest'])
        
        # Individual architecture manifests for compatibility
        for arch in architectures.keys():
            print(f"Creating {arch}-latest manifest...")
            if run_command(['docker', 'manifest', 'create', f'{docker_username}/teaspeak-server:{arch}-latest', f'{docker_username}/teaspeak-server:{arch}-{tag_name}']):
                run_command(['docker', 'manifest', 'push', '--purge', f'{docker_username}/teaspeak-server:{arch}-latest'])
    else:
        print("\nSkipping manifest creation (images not pushed to registry)")
        print("To create manifests later, push the images and run the manifest commands manually.")
    
    print("\nBuild completed!")
    
    if not push_to_registry:
        print("\nLocal images built successfully. To see them, run:")
        print(f"docker images | grep {docker_username}")

if __name__ == "__main__":
    main()