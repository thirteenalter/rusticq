#!/usr/bin/env python3
"""Cloud AI transport for Quickshell 0.3.1.

Only JSON travels over stdin/stdout; API keys live in the Secret Service keyring.
Do not print request payloads, tokens, or responses to a shell log.
"""
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

APP = "quickshell-gruvbox-ai"
PROVIDERS = ("openai", "anthropic", "gemini")
MODEL_PATTERN = re.compile(r"^[A-Za-z0-9_.-]{2,100}$")


def provider_of(value):
    if value not in PROVIDERS:
        raise ValueError("Unknown provider")
    return value


def secret_tool(*args, input_text=None):
    try:
        return subprocess.run(["secret-tool", *args], input=input_text,
                              text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=20)
    except FileNotFoundError:
        raise RuntimeError("Install libsecret (secret-tool) and unlock your keyring")
    except subprocess.TimeoutExpired:
        raise RuntimeError("Keyring request timed out; check Secret Service")


def get_key(provider):
    provider_of(provider)
    result = secret_tool("lookup", "application", APP, "provider", provider)
    if result.returncode == 1 and not result.stderr.strip():
        return ""  # libsecret: no matching credential
    if result.returncode != 0:
        raise RuntimeError("Cannot access keyring. Unlock it or check Secret Service")
    return result.stdout.strip()


def set_key(provider, key):
    provider_of(provider)
    if not key or len(key) > 1000 or "\n" in key:
        raise ValueError("Invalid API key")
    result = secret_tool("store", "--label=Quickshell AI " + provider,
                         "application", APP, "provider", provider,
                         input_text=key)
    if result.returncode != 0:
        raise RuntimeError("Keyring refused the key; unlock your Secret Service keyring")
    return {"ok": True, "message": "API key saved securely"}


def delete_key(provider):
    provider_of(provider)
    result = secret_tool("clear", "application", APP, "provider", provider)
    if result.returncode != 0:
        raise RuntimeError("Could not delete key from keyring")
    return {"ok": True, "message": "API key removed"}


def request_json(url, headers, data):
    request = urllib.request.Request(url, method="POST", headers=headers,
                                     data=json.dumps(data, ensure_ascii=False).encode("utf-8"))
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            return json.loads(response.read(3_000_000).decode("utf-8"))
    except urllib.error.HTTPError as error:
        try:
            detail = json.loads(error.read(4096).decode("utf-8"))
            detail = detail.get("error", {})
            detail = detail.get("message", str(detail)) if isinstance(detail, dict) else str(detail)
        except Exception:
            detail = error.reason
        raise RuntimeError(f"Provider error HTTP {error.code}: {str(detail)[:250]}")
    except urllib.error.URLError as error:
        raise RuntimeError("Network error: " + str(error.reason)[:150])


def ask(provider, model, messages):
    provider_of(provider)
    if not MODEL_PATTERN.fullmatch(model):
        raise ValueError("Invalid model name")
    if not isinstance(messages, list) or not 1 <= len(messages) <= 30:
        raise ValueError("Message history must contain 1 to 30 turns")
    normalized = []
    for entry in messages:
        if not isinstance(entry, dict) or entry.get("role") not in ("user", "assistant"):
            raise ValueError("Invalid message role")
        content = entry.get("content", "")
        if not isinstance(content, str) or len(content) > 12000:
            raise ValueError("Message is too long")
        normalized.append({"role": entry["role"], "content": content})
    key = get_key(provider)
    if not key:
        raise RuntimeError("API key not configured. Open Settings → AI Providers")
    if provider == "openai":
        data = request_json("https://api.openai.com/v1/responses",
                            {"Authorization": "Bearer " + key, "Content-Type": "application/json"},
                            {"model": model, "input": normalized, "store": False})
        segments = []
        for item in data.get("output", []):
            if item.get("type") == "message":
                for part in item.get("content", []):
                    if part.get("type") == "output_text":
                        segments.append(part.get("text", ""))
        answer = "\n".join(segments) or data.get("output_text", "")
    elif provider == "anthropic":
        data = request_json("https://api.anthropic.com/v1/messages",
                            {"x-api-key": key, "anthropic-version": "2023-06-01",
                             "Content-Type": "application/json"},
                            {"model": model, "max_tokens": 1024, "messages": normalized})
        answer = "\n".join(p.get("text", "") for p in data.get("content", []) if p.get("type") == "text")
    else:
        contents = [{"role": "model" if m["role"] == "assistant" else "user",
                     "parts": [{"text": m["content"]}]} for m in normalized]
        data = request_json("https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent",
                            {"x-goog-api-key": key, "Content-Type": "application/json"},
                            {"contents": contents})
        answer = "\n".join(p.get("text", "") for c in data.get("candidates", [])
                           for p in c.get("content", {}).get("parts", []) if "text" in p)
    if not answer:
        raise RuntimeError("Provider returned no text. Try another model or check provider limits")
    return {"ok": True, "reply": answer}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    data = json.loads(sys.stdin.readline() or "{}")
    provider = provider_of(data.get("provider", ""))
    if action == "status":
        return {"ok": True, "configured": bool(get_key(provider))}
    if action == "key-set":
        return set_key(provider, data.get("key", ""))
    if action == "key-delete":
        return delete_key(provider)
    if action == "ask":
        return ask(provider, data.get("model", ""), data.get("messages", []))
    raise ValueError("Unsupported action")


if __name__ == "__main__":
    try:
        result = main()
    except Exception as exc:
        # Print only sanitized errors, never credentials or prompts.
        result = {"ok": False, "message": str(exc)[:300]}
    sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
    sys.stdout.flush()
