#!/usr/bin/env bash

import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from typing import TextIO


def create(name, digests):
    with tempfile.TemporaryDirectory() as tmpdir:
        metadata_file = f"{tmpdir}/metadata.json"
        cmd = [
            "docker",
            "buildx",
            "imagetools",
            "create",
            "--tag",
            name,
            "--metadata-file",
            metadata_file,
            "--progress",
            "none",
        ] + digests
        result = subprocess.run(cmd)
        if result.returncode != 0:
            raise RuntimeError(f"Command failed: {' '.join(cmd)}")
        with open(metadata_file) as f:
            metadata = f.read()
    metadata = json.loads(metadata)
    descriptor = metadata.get("containerimage.descriptor", {})
    digest = descriptor.get("digest")
    return digest


class Artifact:
    def __init__(self, path: str):
        self.path = path
        matrix = path.removeprefix("image-digest-")
        self.torch, self.index, self.python, self.arch = matrix.split(",")
        with open(path) as f:
            self.digest = f.read().strip()

    @property
    def image(self):
        return f"{self.torch},{self.index},{self.python}"

    @property
    def tag(self):
        tag = f"{self.torch}{f'-{self.index}' if self.index else ''}-{self.python}"
        # Tags have limited set of valid character, '+' not included
        # https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
        return re.sub(r"[^a-zA-Z0-9._-]+", "_", tag)


def read_artifacts():
    return [Artifact(path) for path in glob.glob("image-digest-*")]


def collect_image_architectures(artifacts):
    architectures = {}
    for artifact in artifacts:
        architectures.setdefault(artifact.tag, []).append(artifact)
    return architectures


def generate_images(architectures, repository):
    for tag, artifacts in architectures.items():
        yield f"{repository}:{tag}", [f"{repository}@{a.digest}" for a in artifacts]


def merge(images):
    for name, digests in images:
        if len(digests) > 1:
            print(f"Merging multiple architectures for tag {name}: {' '.join(digests)}")
        else:
            print(f"Single image for tag {name} {digests[0]}")
        digest = create(name, digests)
        yield name, digest


def shasums(images):
    for name, digest in images:
        yield f"{digest.removeprefix('sha256:')}  {name}"


def process_all(repository):
    artifacts = read_artifacts()
    architectures = collect_image_architectures(artifacts)
    images = generate_images(architectures, repository)
    merged = merge(images)
    return "\n".join(shasums(merged))


def github(repository, github_output: TextIO):
    shasums = process_all(repository)
    github_output.write("sha256sum<<EOF\n" + shasums + "\nEOF\n")
    tags = json.dumps([s.rsplit(":", 1)[1] for s in shasums.split("\n") if s])
    github_output.write(f"tags={tags}\n")
    print(shasums)


def step():
    repository = os.environ.get("REPOSITORY")
    if repository is None:
        DOCKERHUB_ACCOUNT = os.environ.get("DOCKERHUB_ACCOUNT", "okoko")
        repository = f"docker.io/{DOCKERHUB_ACCOUNT}/python-torch"
    with open(os.environ["GITHUB_OUTPUT"], "a") as f:
        github(repository, f)


if __name__ == "__main__":
    # def create(name, digests):
    #     print(f"Creating image {name} with digests {digests}")
    #     return "sha256:dummy"
    if "GITHUB_OUTPUT" in os.environ:
        step()
    else:
        repository = "localhost:5000/b"
        github(repository, sys.stdout)
