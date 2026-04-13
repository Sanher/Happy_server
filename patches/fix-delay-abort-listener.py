#!/usr/bin/env python3
from pathlib import Path

path = Path('/opt/happy/packages/happy-server/sources/utils/delay.ts')
content = path.read_text(encoding='utf-8').replace('\r\n', '\n')


def replace_once(source: str, old: str, new: str) -> str:
    if old not in source:
        raise SystemExit(f'No se pudo localizar el fragmento esperado en delay.ts: {old}')
    return source.replace(old, new, 1)


content = replace_once(
    content,
    "        const timeout = setTimeout(resolve, ms);",
    """        let settled = false;
        let abortHandler: () => void = () => {};

        const cleanup = () => signal.removeEventListener('abort', abortHandler);
        const resolveOnce = () => {
            if (settled) {
                return;
            }
            settled = true;
            cleanup();
            resolve();
        };

        const timeout = setTimeout(resolveOnce, ms);""",
)
content = replace_once(
    content,
    "        const abortHandler = () => {",
    "        abortHandler = () => {",
)
content = replace_once(
    content,
    "            resolve();\n        };",
    "            resolveOnce();\n        };",
)
content = replace_once(
    content,
    "            resolve();\n        } else {",
    "            resolveOnce();\n        } else {",
)

path.write_text(content, encoding='utf-8')
print('Patched delay.ts abort listener cleanup')
