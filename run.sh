#!/usr/bin/env bash
# Run the app using the project's virtualenv (required for dependencies).
cd "$(dirname "$0")"
.venv/bin/python app.py
