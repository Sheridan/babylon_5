import sys
from pathlib import Path

sys.path.insert(1, sys.argv[1])
import binary_deps

print("\n".join(sorted({n for _f, n in binary_deps.uncovered(Path(sys.argv[2]))})))
