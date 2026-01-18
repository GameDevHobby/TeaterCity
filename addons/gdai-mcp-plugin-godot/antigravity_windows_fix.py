# Proxy for GDAI MCP server for Antigravity IDE for Windows
# https://gdaimcp.com
# Credits thanks to @invisibleacropolis on Discord

import sys
import subprocess
import threading
import os

def forward_stdin(process):
    try:
        while True:
            # Read from stdin (fd 0)
            try:
                chunk = os.read(0, 1024)
            except OSError:
                break
                
            if not chunk:
                break
            process.stdin.write(chunk)
            process.stdin.flush()
    except Exception as e:
        pass

def forward_stdout(process):
    try:
        while True:
            chunk = process.stdout.read(1024)
            if not chunk:
                break
            clean_chunk = chunk.replace(b'\r\n', b'\n')
            
            # Write to stdout (fd 1)
            try:
                os.write(1, clean_chunk)
            except OSError as e:
                try:
                    sys.stdout.buffer.write(clean_chunk)
                    sys.stdout.buffer.flush()
                except Exception as e2:
                    pass
                    
    except Exception as e:
        pass

def forward_stderr(process):
    try:
        while True:
            chunk = process.stderr.read(1024)
            if not chunk:
                break
            try:
                os.write(2, chunk)
            except OSError:
                sys.stderr.buffer.write(chunk)
                sys.stderr.buffer.flush()
    except Exception as e:
        pass

def main():
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        cmd = ["uv", "run", os.path.join(script_dir, "gdai_mcp_server.py")]
        
        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0 # Unbuffered
        )

        # Start threads
        t_in = threading.Thread(target=forward_stdin, args=(process,), daemon=True)
        t_out = threading.Thread(target=forward_stdout, args=(process,), daemon=True)
        t_err = threading.Thread(target=forward_stderr, args=(process,), daemon=True)

        t_in.start()
        t_out.start()
        t_err.start()

        process.wait()
        sys.exit(process.returncode)
    except Exception as e:
        sys.exit(1)

if __name__ == "__main__":
    # Set our own stdout to binary mode just in case
    if sys.platform == "win32":
        import msvcrt
        msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
        msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    main()
