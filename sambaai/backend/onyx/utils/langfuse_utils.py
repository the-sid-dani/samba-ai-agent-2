"""
Enhanced Langfuse tracing utilities for session-level observability.
Focuses on complete conversation flows rather than individual component traces.
"""

import os
from onyx.utils.logger import setup_logger

logger = setup_logger()

# Global Langfuse client - will be initialized if credentials are available
_LANGFUSE_CLIENT = None

def get_langfuse_client():
    """Get the global Langfuse client instance."""
    global _LANGFUSE_CLIENT
    
    if _LANGFUSE_CLIENT is None and os.environ.get("LANGFUSE_SECRET_KEY"):
        try:
            from langfuse import Langfuse
            
            _LANGFUSE_CLIENT = Langfuse(
                secret_key=os.environ.get("LANGFUSE_SECRET_KEY"),
                public_key=os.environ.get("LANGFUSE_PUBLIC_KEY"),
                host=os.environ.get("LANGFUSE_HOST", "https://cloud.langfuse.com"),
                debug=False,
            )
            logger.info("Langfuse client initialized for session-level tracing")
            
        except ImportError:
            logger.warning("Langfuse SDK not available for tracing")
    
    return _LANGFUSE_CLIENT


def flush_langfuse():
    """Flush any pending traces to Langfuse."""
    client = get_langfuse_client()
    if client:
        try:
            client.flush()
        except Exception as e:
            logger.warning(f"Error flushing Langfuse traces: {e}") 