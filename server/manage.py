#!/usr/bin/env python3
"""Owner-only command. Run on the server; never expose it as a web endpoint."""
import argparse
import os
from app import Store

parser = argparse.ArgumentParser()
parser.add_argument("--database", default=os.environ.get("COWRITTEN_DATABASE", "/data/co-written.sqlite"))
sub = parser.add_subparsers(dest="command", required=True)
issue = sub.add_parser("issue", help="Issue one personal token; displayed once")
issue.add_argument("label")
issue.add_argument("--daily-limit", type=int, default=20)
revoke = sub.add_parser("revoke", help="Revoke all tokens for a label")
revoke.add_argument("label")
args = parser.parse_args()
os.umask(0o077)
store = Store(args.database)
if args.command == "issue":
    print(store.issue(args.label, args.daily_limit))
else:
    print(f"Revoked {store.revoke(args.label)} token(s)")
