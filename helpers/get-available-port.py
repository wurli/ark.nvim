# Ask the system for an available port. This will be used to start Ark's LSP.
import socket

def get_available_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

print(get_available_port())

