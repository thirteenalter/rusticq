#!/usr/bin/env python3
"""Offline API-contract smoke tests; never sends a network request."""
from pathlib import Path
import importlib.util
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / "scripts" / "cloud_ai.py"
spec = importlib.util.spec_from_file_location("cloud_ai", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

messages = [{"role": "user", "content": "Hello"}]
responses = {
    "openai": {"output": [{"type": "message", "content": [{"type": "output_text", "text": "Hi from OpenAI"}]}]},
    "anthropic": {"content": [{"type": "text", "text": "Hi from Claude"}]},
    "gemini": {"candidates": [{"content": {"parts": [{"text": "Hi from Gemini"}]}}]},
}
with patch.object(mod, "get_key", return_value="fake-key-for-test"):
    for provider, model, expected in [
        ("openai", "gpt-4.1-mini", "Hi from OpenAI"),
        ("anthropic", "claude-haiku-4-5-20251001", "Hi from Claude"),
        ("gemini", "gemini-2.5-flash", "Hi from Gemini"),
    ]:
        def fake_post(url, headers, data):
            assert "fake-key-for-test" in repr(headers)
            assert data and url.startswith("https://")
            assert "Hello" in repr(data)
            return responses[provider]
        with patch.object(mod, "request_json", side_effect=fake_post):
            result = mod.ask(provider, model, messages)
            assert result["reply"] == expected, (provider, result)

for bad in ("invalid model", "", "../../etc/passwd"):
    try:
        mod.ask("openai", bad, messages)
        raise AssertionError("Invalid model accepted")
    except ValueError:
        pass
print("Cloud AI offline tests passed: OpenAI, Claude, Gemini, invalid models")
