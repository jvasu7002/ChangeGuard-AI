
import re
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse


def validate_github_url(url: str) -> str:
    """Accept only standard public GitHub repository URLs."""

    if not isinstance(url, str):
        raise ValueError("Please enter a valid GitHub repository URL.")

    url = url.strip()
    parsed = urlparse(url)

    if parsed.scheme != "https" or parsed.hostname != "github.com":
        raise ValueError(
            "Only public repositories hosted at https://github.com are supported."
        )

    if parsed.username or parsed.password or parsed.port:
        raise ValueError("Credentials and custom ports are not allowed.")

    if parsed.query or parsed.fragment:
        raise ValueError("Remove query parameters and fragments from the URL.")

    parts = parsed.path.strip("/").split("/")

    if len(parts) != 2:
        raise ValueError(
            "Use the format https://github.com/owner/repository"
        )

    owner, repository = parts
    repository = repository.removesuffix(".git")

    if not re.fullmatch(r"[A-Za-z0-9_.-]+", owner):
        raise ValueError("The GitHub owner name is invalid.")

    if not re.fullmatch(r"[A-Za-z0-9_.-]+", repository):
        raise ValueError("The repository name is invalid.")

    return f"https://github.com/{owner}/{repository}.git"


def clone_public_repository(url: str):
    """
    Clone a public GitHub repository into a temporary directory.

    Returns:
        (temporary_directory, repository_path)

    The caller must clean up the temporary directory after analysis.
    """

    safe_url = validate_github_url(url)
    temporary_directory = tempfile.mkdtemp(prefix="changeguard_")
    repository_path = Path(temporary_directory) / "repository"

    try:
        subprocess.run(
            [
                "git",
                "-c", "protocol.ext.allow=never",
                "-c", "protocol.file.allow=never",
                "clone",
                "--depth", "2",
                "--single-branch",
                "--no-tags",
                safe_url,
                str(repository_path),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=90,
        )

        return temporary_directory, str(repository_path)

    except subprocess.TimeoutExpired as exc:
        import shutil
        shutil.rmtree(temporary_directory, ignore_errors=True)
        raise ValueError(
            "Repository cloning timed out. Try a smaller public repository."
        ) from exc

    except subprocess.CalledProcessError as exc:
        import shutil
        shutil.rmtree(temporary_directory, ignore_errors=True)
        raise ValueError(
            "Could not clone this repository. Check that it is public and the URL is correct."
        ) from exc

    except Exception:
        import shutil
        shutil.rmtree(temporary_directory, ignore_errors=True)
        raise
