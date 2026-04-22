#!/usr/bin/env python3
"""
Package entry-point so the server can be run with:
    python -m grimoire_mcp
"""
from grimoire_mcp.server import mcp


def main():
    import sys

    transport = "stdio"
    port = 8765
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == "--transport" and i + 1 < len(args):
            transport = args[i + 1]
        if arg == "--port" and i + 1 < len(args):
            port = int(args[i + 1])

    if transport == "sse":
        mcp.run(transport="sse", port=port)
    else:
        mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
